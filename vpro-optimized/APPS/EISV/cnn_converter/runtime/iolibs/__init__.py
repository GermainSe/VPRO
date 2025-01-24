"""
This module defines the base types for generalized I/O handling as an interface
to pass inputs and outputs to the VPRO during inference. Three classes interact
in this setting:
* VPROIODataHandler: This is a base class that implements input and output
  handling for the VPRO running parallelized in two threads: one for input
  fetching and one for output passing.
* VPROInputProvider: Abstract base class, which needs to be sub classed by customized
  input sources. It basically defines the fetch_input() method, through which the 
  inputs can be passed to the VPRO by an arbitrary source.
  VPRO
* VPROOutputHandler: Abstract base class, which needs to be sub classed by customized
  output handlers. It basically defines the process_output() method, through which
  VPRO results/outputs are passed to arbitrary output handlers.

The following default types are implemented:
* DefaultVPROInputFileReader: Reads inputs from files (e.g. as defined in input.cfg)
* DefaultVPROOutputFileWriter: Writes outputs to files (e.g. as defined in output.cfg)
"""
from . import tools, io_base_types, io_default_types, custom