from .io_base_types import VPROInputProvider, VPROOutputHandler, VPROIODataHandler
from typing import Iterable, Dict, Union
from .tools import CfgLayerDescription, load_file_input_layers_from_cfg, load_file_output_layers_from_cfg, FileIOInfo
import numpy as np
import os
import logging
from multiprocessing import Queue
import cv2

import sys
sys.path.insert(0, os.path.abspath('../'))
import vprolib as vpro

class VPROWebcamStream(VPROInputProvider, VPROOutputHandler):

    def __init__(self):
        self.inputs = None
        self.cap = cv2.VideoCapture(0)
        self.input_frames = Queue(0)

    def init(self, base):
        self.inputs = base.get_available_layers('input')
        pass

    def done(self, base):
        pass

    def get_config(self, layer: CfgLayerDescription) -> Dict[str, object]:
        pass

    def fetch_input(self) -> Dict[str, np.ndarray]:
        ret, frame = self.cap.read()
        hsize = frame.shape[1]
        vsize = frame.shape[0]
        # cut rectangle ROI from image
        frame = frame[0:vsize, int((hsize - vsize) / 2):int((hsize - vsize) / 2 + vsize), 0:3]

        input_shape = (self.inputs[0].algo_whc[0], self.inputs[0].algo_whc[1])
        frame_small = cv2.resize(frame, input_shape, interpolation=cv2.INTER_NEAREST)

        inpImg = frame_small.copy().astype(np.float32)

        image_frame = frame.copy()
        self.input_frames.put_nowait(image_frame)

        image_bgr = cv2.cvtColor(inpImg, cv2.COLOR_RGB2BGR)
        image_resized = cv2.resize(image_bgr, input_shape, interpolation=cv2.INTER_CUBIC)
        image_resized = np.array(image_resized, dtype='f')
        image_resized -= np.min(image_resized)  # 0 to max
        image_resized /= np.max(image_resized)  # 0 to 1
        # current: WHC
        image_resized = np.transpose(image_resized, (2, 0, 1))

        # data1d_array = data_input_fixp.astype(np.int16).flatten()

        # input_fixed_point_scaling = self.inputs[0].fixedpoint_scaling
        # data_input_fixp = np.int32(image_np_expanded * input_fixed_point_scaling)
        # transfer_frame = data_input_fixp[0, :, :, :].astype(np.int16)
        # input_channel_0 = transfer_frame[0:224, 0:224, 0].flatten().view(np.uint32)
        # input_channel_1 = transfer_frame[0:224, 0:224, 1].flatten().view(np.uint32)
        # input_channel_2 = transfer_frame[0:224, 0:224, 2].flatten().view(np.uint32)

        input_data = {}
        input_data[self.inputs[0]] = image_resized
        return input_data

    def process_output(self, outputs: Dict[CfgLayerDescription, np.ndarray]) -> None:

        output_channels = next(iter(outputs.values())) # WHC

        # output_channels = (input_buffer.view(np.int16)[0:7 * 7 * 125]).copy()        # this is 1d now
        # # convert to 2d arrays
        # output_channels = output_channels.reshape((125, 7, 7))
        # # resort (125 is third index)
        # output_channels = output_channels.transpose((1, 2, 0))

        # image_out = cv2.cvtColor(result_frame, cv2.COLOR_BGR2RGB)
        # concat_images = cv2.hconcat([input_frame, result_frame])
        # _, frame = cv2.imencode('.jpeg', concat_images)

        frame = self.input_frames.get()
        result_frame = vpro.post_processing(output_channels, frame, silent=True).astype(np.uint8)

        cv2.imshow('Result', result_frame)

        c = cv2.waitKey(1)
        if c == 27 or c == 32 or c == 13:  # quit on ESC or space or ENTER
            print("EXIT!")
    def load_input_file(self, file_name):
        pass