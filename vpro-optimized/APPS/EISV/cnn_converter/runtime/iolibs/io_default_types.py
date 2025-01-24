from .io_base_types import VPROInputProvider, VPROOutputHandler, VPROIODataHandler
from typing import Iterable, Dict, Union
from .tools import CfgLayerDescription, load_file_input_layers_from_cfg, load_file_output_layers_from_cfg, FileIOInfo
import numpy as np
import os
import logging

def match_file_io_info_to_layer_cfg(file_io_infos: Iterable[FileIOInfo], 
                                    cfg_layer_descriptions: Iterable[CfgLayerDescription],
                                    reverse=False) -> Dict[Union[FileIOInfo, CfgLayerDescription], Union[FileIOInfo,CfgLayerDescription]]:
    """Creates a dictionary with mapping from matching FileIOInfo objects and CfgLayerDescription objects.
       The equality is defined by their layer indices.

       This function is needed to match two layers in different representations (FileIOInfo and CfgLayerDescription).

       The result will be a one-to-one mapping, which contains all FileIOInfo objects.
       Assertion: find exactly one match for each FileInfoIO object.

       file_io_info:            An iterable of FileIOInfo objects
       cfg_layer_descriptions:  An Iterable of CfgLayerDescription objects
       reverse:                 False:  returns a dict of type Dict[FileIOInfo, CfgLayerDescription], useful for VPROInputFileLoader
                                True:   returns a dict of type Dict[CfgLayerDescription, FileIOInfo], useful for DefaultVPROOutputFileWriter
                                        (reverses the 1-to-1-mapping after creation)
       
    """
    def isequal(a: FileIOInfo, b: CfgLayerDescription) -> bool:
        return a.layer_index == b.layer_index
    
    match_map: Dict[FileIOInfo, CfgLayerDescription] = dict()
    
    for a in file_io_infos:
        match_map[a] = None
        for b in cfg_layer_descriptions:
            if isequal(a,b):
                if match_map[a] is not None:
                    raise AssertionError(f'There are several layers, which match the file io layer {a}:\nalready matched: {match_map[a]}, another match found: {b}')
                match_map[a] = b
        if match_map[a] is None:
            raise AssertionError(f'No layer found, which matches io layer {a}')
    if reverse:
        tmp : Dict[CfgLayerDescription, FileIOInfo] = dict()
        for k,v in match_map.items():
            tmp[v] = k
        match_map = tmp
    return match_map

            

class VPROInputFileLoader(VPROInputProvider):
    """This class replaces the default functionality of the previous cnn_generic 
    implementation w.r.t. to input file loading.
    
    We assume here, that the input.cfg has only inputs for a single inference run,
    i.e. the inputs will be loaded once and in the next iteration fetch_input returns
    None (i.e. no more inputs available)."""

    def __init__(self, input_cfg_file_name):

        # input layers will be initialized in init()
        
        self.input_layer_map = None
        self.file_io_info = load_file_input_layers_from_cfg(input_cfg_file_name)
        
        # defines the maximum number of inputs to be returned
        self.max_inputs = 1
        # defines the number of inputs, that have already been returned by fetch_input
        self.input_counter = 0
        
    def init(self, base):
        # get all available layers from core class
        available_layers = base.get_available_layers()
        # and match them with the input layers, we got from input.cfg
        self.input_layer_map = match_file_io_info_to_layer_cfg(self.file_io_info, available_layers)
        self.reverse_input_layer_map = match_file_io_info_to_layer_cfg(self.file_io_info, available_layers, reverse=True)

        logging.debug(f'{self.__class__.__name__}: found the following matches:')
        for k,v in self.input_layer_map.items():
            logging.debug(f'  {k} --> {v}')
        logging.debug(f'{self.__class__.__name__}: ready.')
    
    def done(self, base):
        logging.debug(f'{self.__class__.__name__} got done signal')

    def get_config(self, layer: CfgLayerDescription) -> Dict[str, object]:
        """Overwrite default configuration:
        disable input checks for all input layers with dynamic shape"""
        is_dynamic_shape = self.reverse_input_layer_map[layer].is_dynamic_shape
        return {'disable_input_checks': is_dynamic_shape}
    
    def fetch_input(self) -> Dict[str, np.ndarray]:
        
        if self.input_counter >= self.max_inputs:
            logging.debug(f'{self.__class__.__name__} I have no more inputs for you (input_counter={self.input_counter} >= max_inputs={self.max_inputs})')
            return None
        
        inputs = {}
        # TODO: make several inputs loading from one file possible
        for file_io, layer_desc in self.input_layer_map.items():
            # load input file
            inputs[layer_desc] = self.load_input_file(file_io.file_name).astype(np.int16)
            # for dynamic shapes file size matters
            if not file_io.is_dynamic_shape:
                inputs[layer_desc].reshape(file_io.data_format_whc[::-1])
        self.input_counter += 1
        return inputs


    def load_input_file(self, file_name):
        """based on vprolib.dma_transfers.transfer_file_to_pl_mem_dma_large"""
        
        # create buffer for input file + load it
        input = np.fromfile(file_name, dtype=np.int16)
        return input
    
    
class DefaultVPROOutputFileWriter(VPROOutputHandler):
    """This class implements the default behaviour of the previous
    cnn_generic script, which dumps the outputs of the VPRO into binary files
    according to the definition in the output.cfg file.
    
    Please note: if VPROIODataHandler.provide_clean_outputs==True, the behaviour might differ
                 from previous implementation, since garbage will be removed, before passing it
                 to this OutputHandler.
    """
    
    def __init__(self, output_cfg_file_name : str):
        self.file_io_info = load_file_output_layers_from_cfg(output_cfg_file_name)

    
    def init(self, base):
        # get all available layers from core class
        available_layers = base.get_available_layers()
        # and match the file_io_info, we got from output.cfg, with the available layers
        self.output_layer_map = match_file_io_info_to_layer_cfg(self.file_io_info, available_layers, reverse=True)


        logging.debug(f'{self.__class__.__name__}: found the following matches:')
        for k,v in self.output_layer_map.items():
            logging.debug(f'  {k} --> {v}')
        logging.debug(f'{self.__class__.__name__}: ready.')
        
        base.configure_output_handler(self, set(self.output_layer_map.keys()))
    
    def done(self, base):
        logging.debug('DefaultVPROOutputFileWriter: got done signal')
    
    
    def process_output(self, outputs: Dict[CfgLayerDescription, np.ndarray]) -> None:
        # based on the implementation in cnn_generic
        
        logging.debug("Dumping Output...")
        # dump output as specified in FileIOInfo, which matches the output_layer
        for output_layer, output_array in outputs.items():
            file_format_shape = self.output_layer_map[output_layer].data_format_whc
            self.dump_output_file(self.output_layer_map[output_layer].file_name, output_array[:file_format_shape[2],:file_format_shape[1],:file_format_shape[0]])
        logging.debug('done dumping output')

    def dump_output_file(self, filename: str, output_array: np.ndarray):
        # implementation based on cnn_generic.dump_output_file()
        logging.debug(f'writing output array with shape {output_array.shape} to file {filename}')
        os.makedirs(os.path.dirname(filename), exist_ok=True)
        with open(filename, "wb+") as newFile:
            newFileByteArray = bytearray(output_array.flatten().view(np.int16))
            # byteswapped = bytearray(len(newFileByteArray))
            # byteswapped[0::2] = newFileByteArray[1::2]
            # byteswapped[1::2] = newFileByteArray[0::2]
            newFile.write(newFileByteArray)
