from abc import ABC, abstractmethod
import numpy as np
from typing import Dict, Iterable, Union, List, AbstractSet
import vprolib as vpro
from overlays.vpro_sys import BaseOverlay
import time
import multiprocessing
from .tools import CfgLayerDescription, parse_layers_in_cfg_file, read_program_data_from_cfg_file
from functools import reduce
import operator
import logging


# Skeleton for LayerConfig encaspulation
# class LayerConfig():
#     layer: CfgLayerDescription
#     clean_output: bool
    


class VPROIOListener(ABC):
    """Base class for listeners of VPROIODataHandler, like VPROInputProvider, VPROOutputHandler.
    This class provides two base methods (init() and done()), which are used to
    notify the VPROIO instances and give opportunity to handle initialization and
    shutdown stuff."""
    
    @abstractmethod
    def init(self, base):
        """This method will be called once before processing starts by the
        managing VPROIOODataHandler instance. The VPPROIODataHandler instance
        passes itself as an argument to this function (param base), in order to allow
        communication with it.
        Information about available layers can be retrieved by calling
        base.get_available_layers().
        No return value is expected.
        """
        pass
    
    @abstractmethod
    def done(self, base):
        """This method will be called once, after the processing has finished,
        by the managing VPROIOODataHandler instance for optional cleanup/shutdown
        handling. The VPPROIODataHandler instance passes itself as an argument
        to this function (param base).
        
        No return value is expected.
        """
        pass


class VPROInputProvider(VPROIOListener):
    """The purpose of the VPROInputProvider class is to define an
    abstract input source within the VPRO demo on an aldec emulation board.
    
    A subclass is supposed to be implemented in order to define a way, how to provide
    input to the application running on the VPRO, like reading input from a list of files on disk or
    reading input data directly from a sensor. The input is passed to the VPRO by calling
    the fetch_input method (VPROIOODataHandler calls this method successively in a
    separate thread).
    """
    
    def get_config(self, layer: CfgLayerDescription) -> Dict[str, object]:
        """Overwrite this method to provide an individual configuration of this InputProvider
        for a given layer. The configuration will be called after fetching the input
        from this provider. Configuration is done by returning a dictionary for
        each layer.
        
        The following parameters can be configured (for each layer individually):
        * 'disable_input_checks': return whether you want to disable all input checks on
                                  the input data you provide (see fetch_input())"""
        return {'disable_input_checks': False}

    @abstractmethod
    def fetch_input(self) -> Dict[CfgLayerDescription, np.ndarray]:
        """Overwrite this method to provide the input data to be processed on the
        VPRO. For each input node/layer, provide an entry in the dictionary with
        the input layers as key (in terms of a CfgLayerDescription object) and the
        input data as value (in terms of a numpy array (numpy.ndarray)).

        The CfgLayerDescription object can be retrieved from the VPROIODataHandler instance
        by calling get_availalbe_layers (usually you would like to do that during the
        init call and then store the layers locally, for which you provide input data).

        This method is called successively during the processing pipeline in a
        separate thread (input thread, using the multiprocessing module), each time when
        the input_parsed register has been set by the EIS-V.

        The returned input data must meet the following requirements:
        * None: to declare that no more inputs are available, which finally tells the
          managing VPROIODataHandler instance to stop processing (after all inputs have been
          processed and passed to the output handlers) and shut down
        * The keys (CfgLayerDescription) must be known to the managing VPROIODataHandler instance,
          i.e. it must be contained in the set of available_layers()
        * The values (np.ndarray) must be either of data type float or int16
          A float array will be automatically converted to the appropriate fixed point format:
          It will be multiplied elementwise by the factor as defined in the CfgLayerDescription
          and then casted to int16.
        * The array's shape must be either one or three dimensional:
          * 3d shape: the shape must be either equal to 'algo_whc' (the algorithmic data shape) or
                      'impl_whc' (shape of the data as allocated in VPRO's memory) as defined in the
                      CfgLayerDescription object. For a default application, you'd probably want to
                      provide data matching the 'algo_whc' shape (, which is normally equal to the impl_whc
                      shape).
                      *** Please note: VPRO memory layout is always row major, i.e. the order of dimensions
                          must be [C, H, W] in numpy (called "data format 'channels first' or CHW" in tensorflow).
                          For historical reasons, cnn_converter consistently uses a reversed shape notation in
                          it's text input and output, i.e. 'whc 2x3x4' in cnn_converter context corresponds
                          to shape (4, 3, 2) in tensorflow/numpy.
          * 1d shape: the number of elements must match the number of elements according to 'algo_whc'
                      or 'impl_whc' shape (i.e. num_elements == w*h*c).
          In case algo_whc and impl_whc are not equal and the data aligns with the 'algo_whc' shape
          (no matter if the data's shape is 3d or 1d), the array will be padded with zeros (after reshaping it
          to 'algo_whc' if neccessary) in order to provide the input as expected by the VPRO/EIS-V.
          In most cases, padding is not required, since algo_whc and impl_whc are equal for normal input 
          layers. But this can become relevant, when feeding intermediate inputs for debug reasons for instance.
          
        Finally, the array will be flattened, or in more detail, we will call data.flatten().view(int32)
        before passing it to the VPRO's memory.
        """
        pass
    
    
class VPROOutputHandler(VPROIOListener):
    """The purpose of the VPROOutputHandler class is to define an
    abstract output handling within the VPRO demo on an aldec emulation board.
    
    A subclass is supposed to be implemented in order to define a way, how to handle
    the outputs that have been processed by the application runnning on the VPRO.
    Examples are writing the outputs to disk, run some postprocessing on it, visualizing
    the outputs, and so on.
    Outputs are passed from the VPRO to the output handler when the managing VPROIODataHandler
    instance calls the output handler's process_output method.

    Multiple output handlers can be registered and configured by calling the VPROIODataHandler's
    configure_output_handler() method for each output handler (e.g. within the init() method call).
    Configuration means: defining the layers the output handler is interested in.
    Usually, you would do the following:
    * Call base.get_available_layers() during the init(self, base) function
    * Define, which layers you are interested by calling base.configure_output_handler()
    * Define in process_outputs() what happens to the output values for all configured layers

    """
    
    @abstractmethod
    def process_output(self, outputs: Dict[CfgLayerDescription, np.ndarray]) -> None:
        """This method must be implemented by the VPROOutputHandler subclass in order to
        define the behaviour of the OutputHandler. It is called successively by the 
        managing VPROIODataHandler instance, as soon as new outputs have been computed
        and are ready to be transferred (GPR rv_output_ready == 1).

        outputs:    a dict containing output data, that have been processed by the VPRO.
                    For all layers, that have been configured for this output handler,
                    an entry in the dict will be added with the layer as key and the
                    data (in terms of a numpy array) as value.
                    The parameter provide_clean_output of VPROIODataHandler defines globally,
                    whether to crop the output according to algo shape (in CNN converter terminology)
                    and thus pass clean output to the output handlers (provide_clean_output=True)
                    or leave the output as is and thus pass output that might contain "garbage"
                    (provide_clean_output=False).
                    Data will NOT be automatically transformed from fixed point format to float.
                    This can be done by the output handler by dividing the data by
                    the layer's param 'fixedpoint_scaling'.
        """
        pass



class VPROIODataHandler(object):
    """The VPROIODataHandler class is the core/base class of running a CNN application on
       the VPRO and defines the interface for passing data to and from the VPRO.

       A VPROIODataHandler instance is responsible for IO data transfers to/from the VPRO
       during inference. It handles all handshaking with the VPRO (via GPRs) and passes
       the inputs from an VPROInputProvider instance to the VPRO and hands over the outputs
       from the VPRO to an VPROOutputHandler instance. The handling is implemented 
       concurrently in two threads:
       * The input_thread fetches the inputs from the VPROInputProvider and passes them to
         the VPRO (copying it to the defined memory address), as soon as the VPRO is ready to
         process new data. Automatic data conversion
         is applied for floating point arrays (see VPROInputProvider.fetch_input()).
       * The output_thread fetches the outputs, which have been computed by the VPRO (by copying
         the outputs at the defined memory addresses), and passes them to the registered
         VPROOutputProvider instances.
       
       Information on available layers of the network are parsed from the input.cfg file and
       are exposed by the method get_available_layers().
        
       This class is also responsible for:
       * Loading the blobs (as defined in input.cfg)
       * Starting the VPRO 
       * Initializing the GPRs of the VPRO in a valid state
       * Stopping the VPRO, if no more inputs are available or the shut_down() function
         has been called.
    """
    
    def __init__(self,
                 input_provider: VPROInputProvider,
                 output_handlers: Iterable[VPROOutputHandler],
                 overlay: BaseOverlay,
                 executable_bin_file: str,
                 input_cfg_filename: str,
                 BASE_ADDR,
                 provide_clean_output=True,
                 max_execution_time=-1,
                 input_buffer=None,
                 output_buffer=None):
        """Creates an instance of VPROIODataHandler. The following parameters are defined:

        input_provider:     Exactly one VPROInputProvider instance must be passed as data source.
        output_handlers:    An arbitrary number of VPROOutputHandlers can be passed, which will be
                            registered as output handlers. Zero output handlers is also possible.
                            For each output_handler all output layers (layer.is_output_layer) will
                            be configured (compare to configure_output_handler() and
                            get_available_layers(mode='output')).
        executable_bin_file:Filename of the executable, which will be transferred via cdma to pl_mem.
        input_cfg_filename: path to input.cfg. This file defines, where to find
                            the relevant binaries for the network (in section CNN descriptor, weights) and
                            the list of available layers (the network is composed of).
        BASE_ADDR:          a global offset, which will be added to all addresses in the memory.
        provide_clean_output:global config param, which defines whether to crop the output according
                            to algo shape (in CNN converter terminology)
                            and thus pass clean output to the output handlers (provide_clean_output=True)
                            or leave the output as is and thus pass output that might contain "garbage"
                            (provide_clean_output=False).
        max_execution_time: Amount of seconds, after which the VPRO will be shutdown. If <= 0, no interrupt
                            will be send at all. An interrupt after a specific time span might be useful,
                            especially for debugging in order to avoid endless loops.
        """
        
        # Inputs and outputs might be transferred in parallel due to multi threading implementation.
        # So we need to use a lock to block the cdma ressource accordingly
        self.cdma_lock = multiprocessing.Lock()
        self.cdma = vpro.CDMA()
        self.cdma.init(overlay.ip_dict['axi_cdma_0']['phys_addr'])
        vpro.set_reset()
        vpro.print_infos()

        # TODO: open serial interface for logging
        # serial output -> uart capture of prints of risc-v

        # BASE_ADDR will be added to each addr for inputs and outputs
        self.BASE_ADDR = BASE_ADDR

        # This flag configures, whether the outputs are being cropped before handing them over to
        # the OutputHandler according to algo vs. mem shape (in CNN converter terminology).
        self.provide_clean_output = provide_clean_output

        self.max_execution_time = max_execution_time

        if input_buffer is None:
            self.input_buffer = vpro.try_allocate(128 * 1024 * 1024)
        else:
            self.input_buffer = input_buffer

        self.output_buffer = output_buffer

        # Transfer the executable to the FPGA
        logging.info("Transferring executable...")
        vpro.transfer_file_to_pl_mem_dma(self.cdma, executable_bin_file, self.input_buffer, 0x10_0000_0000)  # , True, True)
        logging.info(f'\tFile: {executable_bin_file}')

        # Information about program data come from input.cfg file
        for file_name, addr in read_program_data_from_cfg_file(input_cfg_filename, sections_of_interest=['CNN descriptor', 'weights']).items():
            logging.info(f'Transferring {file_name} to {addr}...')
            vpro.transfer_file_to_pl_mem_dma_large(self.cdma, file_name, self.input_buffer, BASE_ADDR + addr, endianessReverse=True)  # , True, True)

        # Availalbe layers of the network are defined as comment lines in the input.cfg file
        self.available_layers = parse_layers_in_cfg_file(input_cfg_filename)
       
        logging.debug(f'{self.__class__.__name__}: The network has the following layers:')
        for l in self.available_layers:
            logging.debug(f'  {l}')
        
        # attributes to administer the input provider and output handlers
        # we have exactly one input provider
        self.input_provider : VPROInputProvider = input_provider
        # we allow to have >= 0 output handlers
        # For each output_handler, we can configure, which outputs are passed to it by calling configure_output_handler()
        # This dict stores those configurations
        self.output_handlers_with_config : Dict[VPROOutputHandler, Iterable[CfgLayerDescription]] = {}

        # populate output_handlers_with_config for the given output_handler with all available output_layers
        for output_handler in output_handlers:
            self.configure_output_handler(output_handler, set(self.get_available_layers(mode='output')))
        
        # we need to keep track of how many inputs and outputs have been provided/handled
        # so that we can make sure that all outputs have been handled at the end (for which we transferred the inputs)
        self.input_counter = multiprocessing.Value('i', 0)
        self.output_counter = multiprocessing.Value('i', 0)

        # flag that is set to true, as soon as the input provider returns None to signal
        # there are no more inputs.
        self.input_exhausted = multiprocessing.Value('i', 0)

        # map of registers for communication between VPRO and ARM system
        # TODO: I guess it would be beneficial, if we move this mapping to
        # the vpro_registers of vpro_lib and the vpro_lib provides
        # readable names to access/set the registers
        self.gpr = {}
        self.gpr["rv_input_parsed"] = 128
        self.gpr["rv_output_ready"] = 132
        self.gpr["arm_input_ready"] = 136
        self.gpr["arm_output_parsed"] = 140
        self.gpr["rv_running"] = 144
        self.gpr[128] = "rv_input_parsed"
        self.gpr[132] = "rv_output_ready"
        self.gpr[136] = "arm_input_ready"
        self.gpr[140] = "arm_output_parsed"
        self.gpr[144] = "rv_running"
        
        self.gpr["syscall_running"] = 88
        self.gpr["syscall_exit_code"] = 92
        self.gpr[88] = "syscall_running"
        self.gpr[92] = "syscall_exit_code"
        
        
        # initialize the gprs in a valid state
        self.initialize_semaphores()
        
        # create two threads, one for input and one for output handling
        self.input_thread = multiprocessing.Process(group=None, name="input", target=self.run_input_thread, args=[])
        self.output_thread = multiprocessing.Process(group=None, name="process", target=self.run_output_thread, args=[])

        # flag for interrupt/shutdown
        self.shutdown = multiprocessing.Value('i', 0)
        
        # how long to sleep between polling VPRO's GPRs
        self.sleep_time = 0.1

    def get_available_layers(self, mode: str='all') -> Iterable[CfgLayerDescription]:
        """Gives information about all available layers, which are part of the network.

        This information is read from input.cfg file (# Layer... lines). The layer
        information are described in terms of CfgLayerDescription data class objects,
        which holds information about layer shape, memory address, scaling factor of
        fixed point format, input/output of the network, etc.

        mode:   a string matching one of the following
                * 'all': returns a list of all available layers in the network (default)
                * 'input': returns a list of all input layers of the network (is_input_layer=True)
                * 'output': returns a list of all output layers of the network (is_output_layer=True)
                * 'input/output': returns a list of all input and output layers of the network (is_input_layer=True or is_output_layer=True)
        """
        valid_modes = ['all', 'input', 'output', 'input/output']
        assert(mode in valid_modes)
        ret : Iterable[CfgLayerDescription] = []

        if mode == 'all':
            ret = [l for l in self.available_layers]
        elif mode == 'input':
            ret = [l for l in self.available_layers if l.is_input_layer]
        elif mode == 'output':
            ret = [l for l in self.available_layers if l.is_output_layer]
        elif mode == 'input/output':
            ret = [l for l in self.available_layers if l.is_input_layer or l.is_output_layer]
        else:
            raise ValueError(f'Unvalid mode: {mode}. Must be one of {valid_modes}')
        
        logging.debug(f'get_available_layers(mode={mode}) will return:')
        for l in ret:
            logging.debug(f'  * {l}')
        return ret

    def configure_output_handler(self, output_handler : VPROOutputHandler, layers_of_interest : AbstractSet[CfgLayerDescription]):
        """Updates the configuration for a given output_handler. The configuration defines, which outputs
        will be passed to the specific output_handler (which layers the output_handler is interested
        in). The caller passes a set of layers, which must be a subset of the available layers. Availalbe layers can be
        retrieved by calling get_available_layers() beforehand.
        A new output_handler instance can be registered by calling this method as well.
           
        layers_of_interest: a set of layers (CfgLayerDescription objects), if empty or None, a possibly
                            existing output_handler entry in the configuration will be removed
        output_handler:     a VPROOutputHandler instance, for which the configuration is stored.
        """
        
        logging.debug(f'configure_output_handler: {output_handler} -> {layers_of_interest}')
        
        # remove output_handler if layers_of_interest is None or empty
        if layers_of_interest is None or len(layers_of_interest) == 0:
            if output_handler in self.output_handlers_with_config:
                del self.output_handlers_with_config[output_handler]
            logging.debug(f'unregistered output_handler {output_handler}')
            return
        
        # we only accept layers, that we know of:
        assert layers_of_interest.issubset(self.available_layers), "Layers of interest is not a subset of available layers"
        
        self.output_handlers_with_config[output_handler] = layers_of_interest

    def get_relevant_output_layers(self) -> AbstractSet[CfgLayerDescription]:
        """Determine a set of relevant output_layers based on layers of interest
        for each output handler. Returns the union of all layers of registered
        output handlers (values in self.output_handlers_with_config).
        The method returns a set of CfgLayerDescription.
        """
        relevant_output_layers : AbstractSet[CfgLayerDescription] = set()
        for requested_outputs in self.output_handlers_with_config.values():
            logging.debug(f'get_relevant_output_layers():')
            for ro in requested_outputs:
                logging.debug(f'get_relevant_output_layers(): {ro}')
            # filter redundancies by using sets
            relevant_output_layers = relevant_output_layers.union(requested_outputs)
        return relevant_output_layers
    
        
    def shut_down(self):
        """Shut down the input and output threads immediately. Calling this function kind of kills
        the processes (at least input and output threads are interrupted) and finally
        self.shutdown_vpro() is called.
        """
        self.shutdown.value = 1

    
    def shutdown_vpro(self):
        """This method is called at the end of the run() method in order to shut down the VPRO."""
        logging.debug("EIS-V gets shut down (rv_running = 0)...")
        self.shut_down()
        vpro.set_gpr(self.gpr["rv_running"], 0x0) # rv_running
        logging.debug("EIS-V exitted successfully")
        time.sleep(0.5)
        vpro.set_reset()
        
    def initialize_semaphores(self):
        """Initializes the GPRs (semaphores) in a valid state, to start the pipeline."""
        vpro.set_gpr(self.gpr["rv_input_parsed"], 0x1)
        vpro.set_gpr(self.gpr["rv_output_ready"], 0x0)
        vpro.set_gpr(self.gpr["arm_input_ready"], 0x0)
        vpro.set_gpr(self.gpr["arm_output_parsed"], 0x1)
        vpro.set_gpr(self.gpr["rv_running"], 0x1)
        
        
    def print_state(self, prefix : str = ""):
        """A method basically implemented for debug purposes, which logs the current state
        of the GPRs and some additional information. Logging is done in DEBUG level."""
        rv_input_parsed = vpro.get_gpr(self.gpr["rv_input_parsed"])
        arm_input_ready = vpro.get_gpr(self.gpr["arm_input_ready"])
        rv_output_ready = vpro.get_gpr(self.gpr["rv_output_ready"])
        arm_output_parsed = vpro.get_gpr(self.gpr["arm_output_parsed"])
        
        logging.debug(f'state: [{prefix.ljust(52)}] {rv_input_parsed}{arm_input_ready}{rv_output_ready}{arm_output_parsed}, ie={self.input_exhausted.value}, ic={self.input_counter.value}, oc={self.output_counter.value}, sd={self.shutdown.value}')

    
    def run_input_thread(self):
        """This function is called by self.input_thread and successively fetches the inputs
        from self.input_provider, transfers it to the VPRO, and handles the signalling regarding
        input data (i.e, VPRO's rv_input_parsed and arm_input_ready registers) within a loop.
        
        The loop is exitted when one of the following cases are true:
        * self.shutdown flag is set to True
        * self.input_provider has no more inputs for processing (i.e. fetch_inputs() returns None)

        Please see VPROInputProvider.fetch_input() doc for more information (especially on the
        required data format of the input data and the implications in this method.)
        """

        logging.debug('input_thread started')
        # a buffer for the inputs (needed for data transfer)
        # the actual initialization will be done when the first input arrives
        # in order to determine the size needed for the buffer
        # TODO: we can initialize it in advance, since we have information about the input
        #       sizes from the input.cfg file
        vpro_input_buffer = self.input_buffer

        while not self.shutdown.value:
            # wait for VPRO's signal "input parsed"
            self.print_state('input_thread: waiting for input parsed (before loop)')
            while vpro.get_gpr(self.gpr["rv_input_parsed"]) == 0x0 and not self.shutdown.value:
                self.print_state('input_thread: waiting for input parsed (in loop)')
                time.sleep(self.sleep_time)
                
            if self.shutdown.value:
                break

            self.print_state('input_thread: waiting for input parsed (in loop) --> done')
            # OK, now we can start providing new input
            # reset semaphore
            vpro.set_gpr(self.gpr["rv_input_parsed"], 0x0)
            
            # fetch inputs and transfer them to vpro's memory according to given input address map
            # TODO: allow keys of type int or str (unique type for all layers or ambigious?)
            inputs : Dict[CfgLayerDescription, np.ndarray] = self.input_provider.fetch_input()

            # handle case that no more input data available (input provider exhausted)
            if inputs is None:
                self.print_state('input_thread: no more inputs, leaving loop')
                break
                # clean up at the end of this method

            # make sure, that all inputs provided are known inputs
            assert(set(inputs.keys()).issubset(self.available_layers)), f'The provided layer keys must be a subset of available_layers\ninputs.keys(): {inputs.keys()}\navailable_layers: {self.available_layers}'

            try:
                # determine biggest input (needed to (re)allocate input_buffer)
                # input_buffer_byte_size = max([input.nbytes for input in inputs.values()])
                input_buffer_byte_size = max([reduce(operator.mul, input.impl_whc, 1) * 2 for input in inputs.keys()])
                # Round up to next 32 bit size, will be cutoff by try_allocate method
                input_buffer_byte_size += 3
            except ValueError:
                logging.debug("No input buffer required...")
                return

            # (re)allocate buffer, if neccessary (either not yet initialized or too small)
            if vpro_input_buffer is None or vpro_input_buffer.nbytes < input_buffer_byte_size & ~3:
                logging.debug(f'reallocating memory for input_buffer:')
                logging.debug(f'   vpro_input_buffer (old):                 {vpro_input_buffer}')
                if vpro_input_buffer is not None:
                    logging.debug(f'   vpro_input_buffer (old):                 {vpro_input_buffer.nbytes}')
                    vpro_input_buffer.freebuffer()
                logging.debug(f'   will allocate new buffer with bytesize:  {input_buffer_byte_size & ~3}')
                vpro_input_buffer = vpro.try_allocate(input_buffer_byte_size)
                logging.debug(f'   vpro_input_buffer (new):                 {vpro_input_buffer}')

            self.print_state('input_thread: transferring inputs...')
            # handle each input
            with self.cdma_lock:
                for ild, input_array in inputs.items():
                    
                    input_cfg = self.input_provider.get_config(ild)

                    if input_cfg['disable_input_checks']:
                        # only check: int16
                        logging.debug(f'disabling all data format checks for input {ild}')
                    else:
                        # we only accept float or int16 format
                        assert(np.issubdtype(input_array.dtype, np.floating) or input_array.dtype==np.int16), f'The dtype for layer {ild} is neither float nor int16, but: {input_array.dtype}'

                        # further, we only accept 3d shape or 1d shape (flattened)
                        assert(len(input_array.shape) == 3 or len(input_array.shape) == 1), f'The shape for layer {ild} is neither 3d nor 1d! input_array.shape: {input_array.shape}'
                        # if it is 3d, it must match exactly the algo_whc or impl_whc shape (reverse order)
                        if (len(input_array.shape) == 3):
                            assert(input_array.shape == ild.algo_whc[::-1] or input_array.shape == ild.impl_whc[::-1]), f'The shape for layer {ild} does not match, must be equal to {ild.algo_whc[::-1]} or {ild.impl_whc[::-1]}, but is: {input_array.shape}'
                        # otherwise it is flattened and its size must match the size of algo_whc or impl_whc
                        else:
                            assert(input_array.size == reduce(operator.mul, ild.algo_whc, 1) or input_array.size == reduce(operator.mul, ild.impl_whc, 1)), f'The size for layer {ild} must be either equal to {reduce(operator.mul, ild.algo_whc, 1)} or {reduce(operator.mul, ild.impl_whc, 1)}, but is: {input_array.size}'
                    
                        # extra handling for floats: convert to int16 according to FixedPointFormat defined by input layer.
                        if np.issubdtype(input_array.dtype, np.floating):
                            fixed_point_factor = ild.fixedpoint_scaling
                            input_array = (input_array * fixed_point_factor).astype(np.int16)

                        # pad input with zeros according to the given memory shape as defined in the layer description (impl.whc)
                        # if neccessary
                        if (input_array.shape != ild.impl_whc) or input_array.size != reduce(operator.mul, ild.impl_whc, 1):
                            padded_input = np.zeros(ild.impl_whc[::-1], np.int16)
                            padded_input[:,:ild.algo_whc[1], :ild.algo_whc[0]] = input_array.view(np.int16).reshape(ild.algo_whc[::-1])
                            padded_input = padded_input.flatten()
                        
                            input_array = padded_input

                    # retrieve target address from address map
                    addr = ild.addr + self.BASE_ADDR
                
                    np.copyto(vpro_input_buffer.view(np.int8)[0:int(input_array.nbytes)], input_array.flatten().view(np.int8))
                    vpro.transfer_buffer_to_pl(
                        self.cdma,
                        vpro_input_buffer,
                        addr,
                        size=(input_array.nbytes+3) & ~3, # can't read this, huh?! Round up to next integer multiple of 32 bit
                        mem_region_fix=0,
                        print_details=False
                    )

            self.input_counter.value += 1

            # notify VPRO, that input is ready to be processed
            self.print_state('input_thread: transferring inputs... --> done')
            self.print_state('input_thread: notify VPRO...')
            vpro.set_gpr(self.gpr["arm_input_ready"], 0x1)
            self.print_state('input_thread: notify VPRO... --> done')

        # clean up and return
        # set flag, that we have nothing more to do (no more inputs available or shutdown)
        self.input_exhausted.value = 1
        vpro_input_buffer.freebuffer()
        self.print_state('input_thread: about to return...')
        return

    def run_output_thread(self):
        """This method is run by the output thread (self.output_thread) and takes care of
        passing the outputs to self.output_handler.
        
        All interaction with the VPRO regarding outputs is handled here. The implementation
        is roughly as follows:
        
        Within a loop:
        * check, if we need to wait for more inputs, which will be processed
        * wait for VPRO's notification "rv_output_ready"
        * copy the relevant outputs from the VPRO via cdma instance
        * notify VPRO, that output has been copied ("arm_output_parsed")
        * crop outputs (if provide_clean_output==True)
        * send output to the output handler via self.output_handler.process_outputs(outputs)
        
        This method "cleans" the outputs on demand before passing them to the output handler:
        if self.provdie_clean_outputs == True, the outputs will be cropped beforehand in order
        to remove possible "garbage" resulting from the memory allocation scheme on the VPRO side.
        """

        self.print_state('output_thread: started')

        # only transfer those outputs, that any of the output handlers is interested in
        relevant_output_layers = self.get_relevant_output_layers()

        vpro_output_buffer = None
        # intitialize buffer with size of the biggest output defined in output_layers
        
        try:
            output_buffer_byte_size = max([reduce(operator.mul, output_layer.impl_whc, 1) * 2 for output_layer in relevant_output_layers])
            # Round up to next 32 bit size, will be cutoff by try_allocate method
            output_buffer_byte_size += 3
        except ValueError:
            logging.debug("No output buffer required...")
            return
            

        # (re)allocate buffer, if neccessary (either not yet initialized or too small)
        if self.output_buffer is None:
            vpro_output_buffer = vpro.try_allocate(output_buffer_byte_size, False)
        else:
            vpro_output_buffer = self.output_buffer

        while not self.shutdown.value:

            # check if we're done, i.e. when no more inputs are available and
            # we have read as many outputs as we have send to the vpro
            if self.input_exhausted.value and (self.input_counter.value == self.output_counter.value):
                self.print_state('output_thread: no more outputs to receive, leaving loop')
                break

            self.print_state('output_thread: waiting for outputs (outside loop)')
            # wait for VPRO's signal output ready
            while vpro.get_gpr(self.gpr["rv_output_ready"]) == 0x0 and not self.shutdown.value:
                self.print_state('output_thread: waiting for outputs (inside loop)')
                if (self.input_exhausted.value and (self.input_counter.value == self.output_counter.value)) or self.shutdown.value:
                    self.print_state('output_thread: no more outputs (2nd checkpoint), leaving loop')
                    break
                time.sleep(self.sleep_time)

            self.print_state('output_thread: process outputs')
            # OK, now we can send the outputs for post processing
            # reset semaphore
            vpro.set_gpr(self.gpr["rv_output_ready"], 0x0)

            # we fetch all relevant outputs at once and store all of them in intermediate variable
            # pass to output handlers afterwards, so that VPRO can continue working
            relevant_outputs : Dict[CfgLayerDescription, np.ndarray] = dict()
            for output_layer in relevant_output_layers:
                num_elements = reduce(operator.mul, output_layer.impl_whc, 1)
                output_byte_size = num_elements * 2 # compute from mem shape of layer config
                
                with self.cdma_lock:
                    vpro.transfer_pl_to_buffer(self.cdma, vpro_output_buffer, addr=output_layer.addr + self.BASE_ADDR, size=output_byte_size)
                    # buffer may be larger than required
                    relevant_outputs[output_layer] = vpro_output_buffer.view(np.int16)[0:int(num_elements)].copy()

                # and now reshape to the given dimensions (we need the reverse order of impl_whc here)
                relevant_outputs[output_layer] = relevant_outputs[output_layer].reshape(output_layer.impl_whc[::-1])
                
            self.print_state('output_thread: process outputs --> done')
            self.print_state('output_thread: notify VPRO')
            # OK, VPRO, you can continue populating the outputs
            vpro.set_gpr(self.gpr["arm_output_parsed"], 0x1)
            
            self.print_state('output_thread: notify VPRO --> done')


            # If we want to do reshaping and cropping of the real data (there might be garbage around it) do so now.
            # We perform the cropping in a separate loop, in order to not block the
            # VPRO for too long time (and sending the output_parsed signal earlier).
            if self.provide_clean_output:
                for output_layer in relevant_outputs.keys():
                    # implementation based on nnquant cpp_frontend.py:
                    # Only return valid output entries
                    h = output_layer.algo_whc[1]
                    w = output_layer.algo_whc[0]
                    relevant_outputs[output_layer] = relevant_outputs[output_layer][:,:h,:w]

            # Now pass the requested outputs to each output handler
            for output_handler, requested_output_layers in self.output_handlers_with_config.items():
                # assemble dict with appropriate key_format
                oh_outputs : Dict[CfgLayerDescription, np.ndarray] = dict()
                for output_layer in requested_output_layers:
                    
                    # TODO: do we need a deep copy here?
                    oh_outputs[output_layer] = relevant_outputs[output_layer]
                output_handler.process_output(oh_outputs)
            
            self.output_counter.value += 1

        self.print_state('output_thread: nothing more to do, leaving')
        # clean up and return
        vpro_output_buffer.freebuffer()
       
    def run(self):
        """This is the main method, which sets up the input, output, and (possibly) a time out thread
        runs them and shuts down the pipeline, when the threads are finished."""

        # initialize thread that waits max time and then shuts down vpro
        if self.max_execution_time > 0:
            def shutdown_after_timeout(timeout=10):
                logging.info(f'--> Waiting for a maxium of {timeout} seconds, before forcing shutdown...')
                time_start = time.time()
                while not self.shutdown.value and time.time()-time_start < int(timeout):
                    logging.debug(f'vpro_algo_demo.shutdown: {self.shutdown.value}')
                    time.sleep(0.10)
                if not self.shutdown.value:
                    logging.info(f'--> Force VPRO to shutdown (max_execution_time={timeout} seconds reached)...')
                    self.shut_down()
                    logging.info('--> Done.')
            to_thread = multiprocessing.Process(group=None, name="input", target=shutdown_after_timeout, args=[self.max_execution_time])
            to_thread.start()

        logging.debug('This is the list of known output handlers:')
        for k,v in self.output_handlers_with_config.items():
            logging.debug(f'  {k}  -> {v}')


        logging.debug('now copying to a list for iteration:')
        # call init from output handler once before the whole loop starts
        for oh in [out_handler for out_handler in self.output_handlers_with_config.keys()]:
            logging.debug(f'  {oh} ---current values in dict---> {self.output_handlers_with_config[oh]}')
            oh.init(self)
        # call init from input provider once before the whole loop starts
        self.input_provider.init(self)
        # Start VPRO
        vpro.release_reset()

        # start the input and output threads...
        self.output_thread.start()
        self.input_thread.start()
        
        
        # ...and wait for them until finished
        self.input_thread.join()
        self.output_thread.join()
        
        # then notify that we're done and shutdown
        self.input_provider.done(self)
                
        # wait for RV to exit (exit code is stored in GPR)
        while vpro.get_gpr(self.gpr["syscall_running"]) != 0x0 and not self.shutdown.value:
            running = vpro.get_gpr(self.gpr["syscall_running"])
            logging.debug(f'syscall still running: {running}')
            time.sleep(0.5)
            
        if vpro.get_gpr(self.gpr["syscall_running"]) == 0x0:
            print("RV exit code: ", vpro.get_gpr(self.gpr["syscall_exit_code"]))
        else:
            print("RV still running. exit code: ", vpro.get_gpr(self.gpr["syscall_exit_code"]))
        
        self.shutdown_vpro()
        for oh in self.output_handlers_with_config:
            oh.done(self)

    
