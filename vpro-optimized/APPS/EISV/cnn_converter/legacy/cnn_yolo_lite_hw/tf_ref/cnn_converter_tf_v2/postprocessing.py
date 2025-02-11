import numpy as np
import cv2


def sigmoid(x):
    return 1. / (1. + np.exp(-x))


def softmax(x):
    e_x = np.exp(x - np.max(x))
    out = e_x / e_x.sum()
    return out


# IoU (Intersection over Union)
def iou(boxA, boxB):
    # boxA = boxB = [x1,y1,x2,y2]; IoU between two boxes with coordinate [left, top, right, bottom]
    # Determine the coordinates of the intersection rectangle
    xA = max(boxA [ 0 ], boxB [ 0 ])
    yA = max(boxA [ 1 ], boxB [ 1 ])
    xB = min(boxA [ 2 ], boxB [ 2 ])
    yB = min(boxA [ 3 ], boxB [ 3 ])

    # Compute the area of intersection
    intersection_area = (xB - xA + 1) * (yB - yA + 1)

    # Compute the area of both rectangles
    boxA_area = (boxA [ 2 ] - boxA [ 0 ] + 1) * (boxA [ 3 ] - boxA [ 1 ] + 1)
    boxB_area = (boxB [ 2 ] - boxB [ 0 ] + 1) * (boxB [ 3 ] - boxB [ 1 ] + 1)

    # Compute the IOU
    iou = intersection_area / float(boxA_area + boxB_area - intersection_area)

    return iou


def non_maximal_suppression(thresholded_predictions, iou_threshold):
    nms_predictions = [ ]
    # Add the best B-Box(with the highest score (final_confidence * best_class_score))
    # because it will never be deleted
    nms_predictions.append(thresholded_predictions [ 0 ])  # .append() adds a single item to the end of the list.

    # For each B-Box (starting from the 2nd) check its IoU with the B-Boxes with highest score
    # thresholded_predictions[i][0] = [x1,y1,x2,y2]
    i = 1
    while i < len(thresholded_predictions):
        n_boxes_to_check = len(nms_predictions)
        # print('N boxes to check = {}'.format(n_boxes_to_check))
        to_delete = False

        j = 0
        while j < n_boxes_to_check:
            curr_iou = iou(thresholded_predictions [ i ] [ 0 ], nms_predictions [ j ] [ 0 ])
            if (curr_iou > iou_threshold):
                to_delete = True  # delete
            # print('Checking box {} vs {}: IOU = {} , To delete = {}'.format(thresholded_predictions[i][0],nms_predictions[j][0],curr_iou,to_delete))
            j = j + 1

        if to_delete == False:  # not delete
            nms_predictions.append(thresholded_predictions [ i ])
        i = i + 1
    return nms_predictions


# predictions are cnn output tiny yolov2 (13x13x125), yolo-lite(7x7x125)
def postprocessing(predictions, input_img_path, score_threshold, iou_threshold, input_height, input_width):
    input_image = cv2.imread(input_img_path)
    input_image = cv2.resize(input_image, (input_height, input_width), interpolation=cv2.INTER_CUBIC)

    # cnn output 13x13x125
    n_grid_cells = 7  # output size of the last layer (7x7 cells)
    n_b_boxes = 5  # 5 object detector for each cell 5x(7x7x25)

    # each detector produces 25 value for each cell
    n_classes = 20  # class probabilities of total 20 classes
    n_b_box_coord = 4  # for the calculation of bounding box (tx, ty, tw, th)
    n_b_box_cofidence = 1  # confidence score of the bounding box

    # Names and box colors for each class
    classes = ["aeroplane", "bicycle", "bird", "boat", "bottle", "bus", "car", "cat", "chair", "cow", "table",
               "dog", "horse", "motorbike", "person", "pottedplant", "sheep", "sofa", "train", "tvmonitor"]
    colors = [(254.0, 254.0, 254), (239, 211, 127), (225, 169, 0), (211, 127.0, 254), (197, 84, 127), (183, 42, 0),
              (169, 0.0, 254), (155, -42, 127), (141, -84, 0), (127.0, 254.0, 254), (112, 211, 127), (98, 169, 0),
              (84, 127.0, 254), (70, 84, 127), (56, 42, 0), (42, 0.0, 254), (28, -42, 127), (14, -84, 0),
              (0, 254, 254), (-14, 211, 127)]

    # Pre-computed object shapes for 5 detectors (k=5 B-Boxes)
    # anchors = [width_0, height_0, width_1, height_1, .... width_4, height_4]
    anchors = [ 1.08, 1.19, 3.42, 4.41, 6.63, 11.38, 9.42, 5.11, 16.62, 10.52 ]

    thresholded_predictions = [ ]
    print('Thresholding on (Objectness score)*(Best class score) with threshold = {}'.format(score_threshold))

    # IMPORTANT: reshape to have shape = [ 13 x 13 x (5 B-Boxes) x (4 Coords + 1 Obj score + 20 Class scores ) ]
    # From now on the predictions are ORDERED and can be extracted in a simple way!
    # We have 13x13 grid cells, each cell has 5 B-Boxes, each B-Box has 25 channels with 4 coords, 1 Obj score , 20 Class scores
    # E.g. predictions[row, col, b, :4] will return the 4 coords of the "b" B-Box which is in the [row,col] grid cell
    predictions = np.reshape(predictions, (7, 7, 5, 25))

    # IMPORTANT: Compute the coordinates and score of the B-Boxes by considering the parametrization of YOLOv2
    for row in range(n_grid_cells):
        for col in range(n_grid_cells):
            for b in range(n_b_boxes):  # number of bounding box or detector 5

                tx, ty, tw, th, tc = predictions [ row, col, b, :5 ]  # :5 first 5 values

                # IMPORTANT: (416 img size) / (13 grid cells) = 32! for tiny yolov2
                # IMPORTANT: (224 img size) / (7 grid cells) = 32! for yolo-lite
                # YOLOv2 predicts parametrized coordinates that must be converted to full size
                # box_coordinates = parametrized_coordinates * 32.0 ( You can see other EQUIVALENT ways to do this...)
#                print('(x, y, b) = ({}, {}, {})'.format(row, col, b))
#                print('(tx, ty) = ({}, {}) (tw, th) = ({}, {})' .format(tx, ty, tw, th))
                #print('(x, y, b) = ({}, {}, {}) tc = {}' .format(row, col, b, tc))
                # center coordinates of box
                center_x = (float(col) + sigmoid(tx)) * 32.0
                center_y = (float(row) + sigmoid(ty)) * 32.0

                # width and heights of 5 detectors (5 bounding box)
                roi_w = np.exp(tw) * anchors [ 2 * b + 0 ] * 32.0
                roi_h = np.exp(th) * anchors [ 2 * b + 1 ] * 32.0

                # confidence score of each bounding box (total 5)
                final_confidence = sigmoid(tc)

                # Softmax classification
                class_predictions = predictions [ row, col, b, 5: ]  # 5: last 20 values for classification
                class_predictions = softmax(class_predictions)

                class_predictions = tuple(class_predictions)
                best_class = class_predictions.index(max(class_predictions))  # index of the best class of a cell
                best_class_score = class_predictions [ best_class ]  # score of the best class of a cell

                # Compute the final coordinates on both axes
                left = int(center_x - (roi_w / 2.))
                right = int(center_x + (roi_w / 2.))
                top = int(center_y - (roi_h / 2.))
                bottom = int(center_y + (roi_h / 2.))

                if ((final_confidence * best_class_score)
                        > score_threshold):
                    # update thresholded_predictions for further "non_maximal_suppression"
                    thresholded_predictions.append(
                        [ [ left, top, right, bottom ], final_confidence * best_class_score, classes [ best_class ] ])

    # Sort the B-boxes by their final score (final_confidence * best_class_score)
    thresholded_predictions.sort(key=lambda tup: tup [ 1 ], reverse=True)  # reverse=True: sorted in descending order
    # len(thresholded_predictions): number of box left
    print('Printing {} B-boxes survived after score thresholding:'.format(len(thresholded_predictions)))
    for i in range(len(thresholded_predictions)):
        print('B-Box {} : {}'.format(i + 1, thresholded_predictions [ i ]))

    # Non maximal suppression
    print('Non maximal suppression with iou threshold = {}'.format(iou_threshold))
    nms_predictions = non_maximal_suppression(thresholded_predictions, iou_threshold)

    # Print survived b-boxes
    print('Printing the {} B-Boxes survived after non maximal suppression:'.format(len(nms_predictions)))
    for i in range(len(nms_predictions)):
        print('B-Box {} : {}'.format(i + 1, nms_predictions [ i ]))

    # Draw final B-Boxes and label on input image
    for i in range(len(nms_predictions)):
        color = colors [ classes.index(nms_predictions [ i ] [ 2 ]) ]
        best_class_name = nms_predictions [ i ] [ 2 ]

        # Put a class rectangle with B-Box coordinates and a class label on the image
        input_image = cv2.rectangle(input_image, (nms_predictions [ i ] [ 0 ] [ 0 ], nms_predictions [ i ] [ 0 ] [ 1 ]),
                                    (nms_predictions [ i ] [ 0 ] [ 2 ], nms_predictions [ i ] [ 0 ] [ 3 ]), color)
        cv2.putText(input_image, best_class_name, (
            int((nms_predictions [ i ] [ 0 ] [ 0 ] + nms_predictions [ i ] [ 0 ] [ 2 ]) / 2),
            int((nms_predictions [ i ] [ 0 ] [ 1 ] + nms_predictions [ i ] [ 0 ] [ 3 ]) / 2)), cv2.FONT_HERSHEY_SIMPLEX,
                    1,
                    color, 3)
    return input_image