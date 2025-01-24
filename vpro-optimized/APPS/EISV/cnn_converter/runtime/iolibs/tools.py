from typing import NamedTuple, Iterable, Dict, Tuple, List
from dataclasses import dataclass
import regex as re


def get_class( kls ):
    """Get class from a str description of the class.
    We need such a function in order to dynamically instantiate the VPROInputProvider and
    VPROOutputHandler class, that are defined by command line arguments.

    From https://stackoverflow.com/questions/452969/does-python-have-an-equivalent-to-java-class-forname
    """

    parts = kls.split('.')
    module = ".".join(parts[:-1])
    m = __import__( module )
    for comp in parts[1:]:
        m = getattr(m, comp)            
    return m


class CfgLayerDescription(NamedTuple):
# @dataclass(eq=True, frozen=True) # make it immutable and thus hashable, we need that to use CfgLayerDescription instances in dicts, sets, etc.
# class CfgLayerDescription:
    """A simple data container class for the description of a layer defined by input
    and output cfg files."""
    algo_whc: Tuple[int, int, int]
    impl_whc: Tuple[int, int, int]
    layer_name: str
    layer_index: int
    addr: int
    fixedpoint_scaling: float
    is_input_layer: bool
    is_output_layer: bool

def parse_layers_in_cfg_file(cfg_file_name: str) -> Iterable[CfgLayerDescription]:
    """Parses a cfg file for the VPRO, which can either be an input.cfg or output.cfg.
    
    For each section in the file (starting with "==") an entry in the returned dictionary
    is added consisting of the identifier (the str behind "==") and as entries all
    the items within that section. The information for each entry is encoded as a
    CfgLayerDescription data class. Not provided information is set to None.
    """

    ret : Iterable[CfgLayerDescription] = []

    for line in open(cfg_file_name, "r"):
        line = line.strip()
        
        
        algo_whc = None
        impl_whc = None
        layer_name = None
        layer_index = None
        fixedpoint_scaling = 0.0
        is_input_layer = False
        is_output_layer = False
        # if current_section_name in ['input', 'output']:
        m = re.match('# Layer \'(.*)\' \(([0-9]+)\): (I?)(O?) ?whc ([0-9]+)x([0-9]+)x([0-9]+), mem ([0-9]+)x([0-9]+)x([0-9]+) @ ([0-9a-fA-Fx]+).*fp-scaling ([-0-9.]+)', line) # match(): at start of string only
        if m:
            layer_name = m.group(1)
            layer_index = int(m.group(2))
            is_input_layer = m.group(3) == 'I'
            is_output_layer = m.group(4) == 'O'
            algo_whc = tuple([int(x) for x in m.group(5, 6, 7)])
            impl_whc = tuple([int(x) for x in m.group(8, 9, 10)])
            address = int(m.group(11), 0)
            fixedpoint_scaling = float(m.group(12))
            
            #raise NotImplementedError('parsing for additional layer information (from previous line) not yet implemented')
            # algo_whc, impl_whc, layer_name, layer_index = ...(previous_line)

            ret.append(
                CfgLayerDescription(
                    addr=address,
                    layer_name=layer_name,
                    layer_index=layer_index,
                    algo_whc=algo_whc,
                    impl_whc=impl_whc,
                    fixedpoint_scaling=fixedpoint_scaling,
                    is_input_layer=is_input_layer,
                    is_output_layer=is_output_layer)
            )

    return ret

def read_program_data_from_cfg_file(cfg_file_name: str, sections_of_interest = ['CNN descriptor', 'weights']) -> Dict[str, int]:
    """Parses a cfg file for the VPRO, which can either be an input.cfg or output.cfg.
    
    # TODO: * only reads uncommented lines, which are located in a section of interest
    Mimics the behaviour of reading the input and output.cfg files as the ISS does:
    In order to retrieve information w.r.t. file IO only lines without comments are considered
    (in the input/output section).
    """

    ret : Dict[str, int] = dict()

    new_section_str = '# == '

    found_section = False
    
    for line in open(cfg_file_name, "r"):
        line = line.strip()
        # do we have a new section?
        if line.startswith(new_section_str):
            found_section = False
            for soi in sections_of_interest:
                if line.startswith(new_section_str + soi):
                    found_section = True
                    break
        
        # only parse, if we are in a section of interest and have a line without '#'
        if not found_section or line.startswith('#'):
            continue
                
        # populate list with information
        # now we have the line of interest, and the previous one
        content_tmp = line.split(' ')
        file_name = content_tmp[0]
        address = int(content_tmp[1], 0)
        ret[file_name] = address

    return ret

class FileIOInfo(NamedTuple):
# @dataclass(eq=True, frozen=True) # make it immutable and thus hashable, we need that to use FileIOInfo instances in dicts, sets, etc.
    """A simple data container class for the description of a layer w.r.t. file IO as defined by
    input.cfg and output.cfg files.
    Used by parse_cfg_file_wrt_file_io, load_file_input_layers_from_cfg, load_file_output_layers_from_cfg
    to encode relevant I/O information for default handlers (VPROInputFileLoader, VPROOutputFileWriter)"""
    file_name: str
    layer_index: int
    data_format_whc: Tuple[int, int, int]
    is_dynamic_shape: bool # defines, whether the shape of the data is of dynamic nature: if true we consider the data_format as a maximum shape, but also less elements are allowed


def load_file_input_layers_from_cfg(cfg_file_name: str):
    """Convenience method to get all input file information from the cfg file.
    See parse_cfg_file_wrt_file_io for more information.
    """
    return parse_cfg_file_wrt_file_io(cfg_file_name, ls_targets=['load'])

def load_file_output_layers_from_cfg(cfg_file_name: str):
    """Convenience method to get all output file information from the cfg file.
    See parse_cfg_file_wrt_file_io for more information.
    """
    return parse_cfg_file_wrt_file_io(cfg_file_name, ls_targets=['save'])


def parse_cfg_file_wrt_file_io(cfg_file_name: str, ls_targets: Iterable[str]) -> Iterable[FileIOInfo]:
    """Extracts file input/output information from a cfg file (generated from the cnn_converter framework).
    The file I/O information is stored in commented lines, one for each layer and for which the input/output
    data should be loaded/stored from/in files. This method is used by the default I/O handlers
    VPROInputFileLoader and VPROOutputFileWriter.
    
    The relevant lines with information start with '# file' and contain the following information,
    which is stored in FileIOInfo objects as following:
    * load|store:   str -- defines, whether data should be loaded from or stored in the file for this layer
    * layer_name:   str -- the layer's name (not extracted)
    * layer_index:  int -- the layer's index, used for matching the FileIOInfo with CfgLayerDescription objects
                    from the VPROIODataHandler instance
    * whc:          Tuple(int, int, int) -- the data format of the file (the shape of the array contained in the file)

    The load|store str is only used for filtering the relevant matches; can be parametrized with argument ls_targets.
    All other data are stored in the FileIOInfo objects and then returned by the method.

    params:
    cfg_file_name:  str -- the name of the config file (generated by the cnn_converter framework)
    ls_targets:     Iterable[str] -- an enumeration of load store targets, which are used for filtering.
                         ['load'] for returning all inputs, which must be read from file
                         ['store'] for returning all outputs, which must be written to file
                         ['load', 'store'] for all
    """

    
    valid_ls_targets = ['load', 'save']

    for ls_target in ls_targets:
        assert ls_target in valid_ls_targets
    ret : List[FileIOInfo] = []

    for line in open(cfg_file_name, "r"):
        m = re.match('# file (load|save) \'(.*)\' \(([0-9]+)\): \'(.*)\' format whc ([0-9]+)x([0-9]+)x([0-9]+) (!?)dynamic_shape', line)
        # The "dynamic_shape" part is only present for input layers,
        # so try without "dynamic shape" expression again, if it didn't match
        if not m:
            m = re.match('# file (load|save) \'(.*)\' \(([0-9]+)\): \'(.*)\' format whc ([0-9]+)x([0-9]+)x([0-9]+)', line)
        if m:
            # load/save
            load_save = m.group(1)
            if load_save in ls_targets:
                # # layer_name, not needed here
                # layer_name = m.group(2)
                # layer_index
                layer_index = int(m.group(3))
                # file name
                file_name = m.group(4)
                # format whc
                whc = (int(m.group(5)), int(m.group(6)), int(m.group(7)))

                is_dynamic_shape = False
                if m.lastindex > 7:
                    assert(m.group(8) in ['', '!']) # '' declares that shape is dynamic, '!' declares shape is not dynamic
                    is_dynamic_shape = m.group(8) == ''
                
                ret.append(FileIOInfo(
                    file_name=file_name,
                    layer_index=layer_index,
                    data_format_whc=whc,
                    is_dynamic_shape=is_dynamic_shape
                ))
    return ret
            