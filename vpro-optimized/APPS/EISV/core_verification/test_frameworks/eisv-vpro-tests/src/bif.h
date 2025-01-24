#ifndef BIF_H
#define BIF_H

#include <inttypes.h>
#include <bitset>
#include <cstdint>
#include <vector>
#include <cassert>

// Binary InterFace CNN description common to generator (host) and EISV runtime
// Stuff exclusive to host or EISV does NOT go here!

// Endianness
// Binary data generation relies on common endianness of host and EISV
// EISV is little endian (at least for data).
// [main.bin is swapped to 32-bit big endian (make all calls objcopy --reverse-bytes=4)]

typedef uint64_t mm_addr_type; // FIXME why 64?
typedef uint32_t mm_size_type;
typedef int16_t weight_t;
typedef int16_t qparam_t;
typedef int16_t data_t;

typedef std::vector<uint8_t> Blob;

// legacy char* instead of std::string for compatibility with embedded gcc.
// RISCV target: ld _sometimes_ says "undefined reference to `__dso_handle'" if anything related to string, new etc. is compiled

const char* mmAddrStr(mm_addr_type addr);
const char* to_bin(size_t const size, void const *const ptr);


// enums defined outside BIF namespace, "enum" instead of "enum class" -> global constants
//  + human-readable code (avoid cluttering prefixes BIF::COMMAND_SEGMENT_TYPE::)
//  - all enum values must be globally unique

enum POOLTYPE : uint8_t {
  NO_POOLING = 0,
  MAX_POOLING = 1, // ideas: min pooling, avg pooling?
};
const char* to_char(POOLTYPE type);

/**
 * To identify buffers (double-buffering) inside the segment generation process
 */
enum BUFFER : uint8_t{
    A = 0,
    B = 1
};

/**
 * For VPRO Commands
 */
enum VPRO_TYPE : uint8_t  {
    conv_start = 0,
    conv_add = 1,
    relu_pool = 2,
    shift_store = 3,
    residual = 4,
    conv_transpose_start = 5,
    conv_transpose_add = 6,
    conv1d_start = 7,
    conv1d_add = 8,
    shift_store_1d = 9,
    concatenate = 10,
    depth_to_space = 11
};
const char* to_char(VPRO_TYPE type);

enum ACTIVATION : uint8_t {
  LEAKY = 0,
  RECT = 1,
  RELU6 = 2,
  SIGMOID = 3,
  NO_ACTIVATION = 255
};
const char* to_char(ACTIVATION type);

enum LAYERTYPE : uint8_t {
  RESIDUAL = 0,
  CONV2 = 1,
  DEPTHWISE_CONV2 = 2,
  UNKNOWN_LAYERTYPE = 3,
  CONV2_TRANSPOSE = 4,
  CONV1 = 5,
  CONCATENATE = 6,
  DEPTH_TO_SPACE = 7,
  SCATTER_TO_GRID = 8,
  DYNAMIC_AXIS = 9
};
const char* to_char(LAYERTYPE type);

enum COMMAND_SEGMENT_TYPE : uint8_t {
  DMA_CMD = 0,
  VPRO_CMD = 1,
  DMA_WAIT = 2,
  VPRO_WAIT = 3,
  DMA_BLOCK = 4,
  BOTH_SYNC = 5,
  SCATTER_CMD = 6,
  UNKNOWN_COMMAND_SEGMENT_TYPE = 255
};
const char* to_char(COMMAND_SEGMENT_TYPE type);

// BEGIN based on ISS/common_lib/vpro/dma_cmd_struct.h
/**
 * DMA Commands can load data 2D, or 1D
 * DMA Commands can load data extern -> local, or local -> extern
 */
enum DMA_DIRECTION : uint8_t {
  /**
   * extern to local, 1D
   */
  e2l1D = 0,
  /**
   * extern to local, 2D
   */
  e2l2D = 1,
  /**
   * local to extern, 1D
   */
  l2e1D = 2,
  /**
   * local to extern, 2D
   */
  l2e2D = 3,
  /**
   * DMA Command Loop Generation
   */
  loop = 4  // may not be used in COMMAND_DMA directly!
};
const char* to_char(DMA_DIRECTION dir);

namespace BIF {
  /**
   * DMA Commands can be created by DCache (Hardware) by loading one of this structs
   * These structs need to match 32-bytes (loaded parallel by dcache)
   * These elements need to be placed aligned to memory space
   *    in Instanciation: __attribute__ ((aligned (16)))
   */
  struct  COMMAND_DMA {
    /**
     * this Commands direction (e2l/l2e) and dimension (1D/2D)
     */
    DMA_DIRECTION direction{};
    bool isBiasOffset{false}; // no longer used by hardware but still useful for debug
    bool isKernelOffset{false}; // no longer used by hardware but still useful for debug
      // switch padding on/off per transfer; padding length is configured layer-wide via LAYER.pad
    uint8_t padding{}; // 7 downto 0 := '3 = left, '2 = bottom, '1 = right, '0 = top |  order see CommandDMA::PAD

    uint32_t cluster{};
    uint32_t unit_mask{};
    uint32_t mm_addr{}; // byte address of first non-padding element
    uint32_t mm_addr_64{};  // used in simulation (ISS) @ 02.06.2023 -> order of elements changed

    uint32_t lm_addr{}; // word address
    uint16_t y_leap{}; // distance of last transferred element in row n to first element of row n+1; =1 for gapless
                       // misleadingly called "x_stride" in ISS and HW
    uint16_t x_size{}; // in 16-bit words
    uint16_t y_size{}; // in 16-bit words

    COMMAND_SEGMENT_TYPE type{DMA_CMD};
//    uint16_t &word_count = x_stride;
//    uint8_t filler[6]{};    // to match 32-byte [6]
    
    const char* to_char() const {
      static char buf[1024];
      sprintf(buf, "direction %s, " "isKernelOffset %d, " "isBiasOffset %d, " "cluster %d, "
              "unit_mask %s, " "mm_addr 0x%08" PRIx32 ", " "lm_addr 0x%06" PRIx32 ", " "y_leap %d, " "x_size %d, "
              "y_size %d, " "pad_0 %d, " "pad_1 %d, " "pad_2 %d, " "pad_3 %d",
              ::to_char(direction), isKernelOffset, isBiasOffset, cluster, to_bin(32, &unit_mask),
              mm_addr, lm_addr, y_leap, x_size, y_size, (padding & 0b0001), (padding & 0b0010), (padding & 0b0100), (padding & 0b1000));
      return buf;
    }
    const char* unit_mask_to_char() const {
      static char buf[32];
      sprintf(buf, "%d", 
      		  unit_mask);
      return buf;
    }

    bool equals(const COMMAND_DMA &ref) const {
      bool equal = true;
      equal &= (ref.direction == direction);
//      equal &= (ref.isBiasOffset == isBiasOffset);
//      equal &= (ref.isKernelOffset == isKernelOffset);
      equal &= (ref.cluster == cluster);
      equal &= (ref.unit_mask == unit_mask);
      //equal &= (ref.mm_addr == mm_addr);//FIXME: uncomment this, once MM addresses are handled correctly
      equal &= (ref.lm_addr == lm_addr);
      equal &= (ref.y_leap == y_leap);
      equal &= (ref.x_size == x_size);
      equal &= (ref.y_size == y_size);
      equal &= (ref.padding == padding);
      return equal;
    }
  };
  static_assert(sizeof(COMMAND_DMA) == 32, "Memory layout of packed struct");
  // END bases on ISS/common_lib/vpro/dma_cmd_struct.h


    /**
     * COMMAND_DMA_LOOP usage requires a COMMAND_DMA afterwards (base)
     */
    struct COMMAND_DMA_LOOP {
        DMA_DIRECTION direction{loop};// '0.
        uint8_t cluster_loop_len{};
        int8_t cluster_loop_shift_incr{};
        uint8_t unit_loop_len{};
        int8_t unit_loop_shift_incr{};  // '1.
        uint8_t inter_unit_loop_len{};
        uint8_t struct_padding0[2]{};
        int16_t lm_incr{};  // 13-bit signed! // '2.
        uint8_t struct_padding1[2]{};
        int32_t mm_incr{}; // '3.
        uint16_t dma_cmd_count{};// '4.
        uint8_t struct_padding2[12]{};//pad structure to 32 byte
        COMMAND_SEGMENT_TYPE type{DMA_CMD};

        const char *to_char() const {
            static char buf[1024];
            sprintf(buf, " DMA LOOP, " "cluster_loop_len %d, " "cluster_loop_shift_incr %d, " "unit_loop_len %d, "
                         "unit_loop_shift_incr %d, " "inter_unit_loop_len %d, " "lm_incr 0x%04" PRIx32 ", " "mm_incr 0x%08" PRIx32 ", "
                         "dma_cmd_count %d",
                    cluster_loop_len, cluster_loop_shift_incr, unit_loop_len, unit_loop_shift_incr,
                    inter_unit_loop_len, lm_incr, mm_incr, dma_cmd_count);
            return buf;
        }

        bool equals(const COMMAND_DMA_LOOP &ref) const {
            bool equal = true;
            equal &= (ref.direction == direction);
            equal &= (ref.cluster_loop_len == cluster_loop_len);
            equal &= (ref.cluster_loop_shift_incr == cluster_loop_shift_incr);
            equal &= (ref.unit_loop_len == unit_loop_len);
            equal &= (ref.unit_loop_shift_incr == unit_loop_shift_incr);
            equal &= (ref.inter_unit_loop_len == inter_unit_loop_len);
            equal &= (ref.lm_incr == lm_incr);
            equal &= (ref.mm_incr == mm_incr);
            equal &= (ref.dma_cmd_count == dma_cmd_count);
            return equal;
        }
    };

    static_assert(sizeof(COMMAND_DMA_LOOP) == 32, "Memory layout of packed struct");


  // BEGIN based on cnn_struct_reduced.h g9114dd8
  struct  COMMAND_VPRO {
    //    uint8_t command{};
    VPRO_TYPE command{};
    uint8_t lane{};
    uint16_t buffer{};
//    bool four_way{};
//    uint16_t xend_1[4]{}, xend_2[4]{}, yend[4]{}, offset[4]{};
    uint16_t xend_1{};
    uint16_t xend_2{};
    uint16_t yend{};
    uint16_t offset{};
//    uint16_t *dst_offset = xend_2;

    uint16_t shift_right{};
    uint16_t kernel_load_buffer_l0{};
    uint16_t kernel_load_buffer_l1{};
    uint16_t bias_load_buffer_l0{};
    uint16_t bias_load_buffer_l1{};
    uint8_t struct_padding[9]{}; //pad structure to 32 byte
    COMMAND_SEGMENT_TYPE type{COMMAND_SEGMENT_TYPE::VPRO_CMD};

    const char* to_char() const {
      static char buf[1024];
      sprintf(buf, "%s, " "lane %d, " "buffer %d, " "xend_1 %d, " "xend_2 %d, "
              "yend %d, " "offset %d, " "kernel_load_buffer_l0 %d, "
              "kernel_load_buffer_l1 %d, " "bias_load_buffer_l0 %d, " "bias_load_buffer_l1 %d",
              ::to_char(command), lane, buffer, xend_1, xend_2, yend, offset,
              kernel_load_buffer_l0, kernel_load_buffer_l1, bias_load_buffer_l0, bias_load_buffer_l1);
      return buf;
    }

    bool equals(const COMMAND_VPRO &ref) const {
      bool equal = true;
      equal &= (ref.command == command);
      equal &= (ref.lane == lane);
      equal &= (ref.buffer == buffer);
      equal &= (ref.xend_1 == xend_1);
      equal &= (ref.xend_2 == xend_2);
      equal &= (ref.yend == yend);
      equal &= (ref.offset == offset);
      equal &= (ref.kernel_load_buffer_l0 == kernel_load_buffer_l0);
      equal &= (ref.kernel_load_buffer_l1 == kernel_load_buffer_l1);
      equal &= (ref.bias_load_buffer_l0 == bias_load_buffer_l0);
      equal &= (ref.bias_load_buffer_l1 == bias_load_buffer_l1);
      return equal;
    }
  };
  static_assert(sizeof(COMMAND_VPRO) == 32, "Memory layout of packed struct");

struct  COMMAND_SCATTER {
  int16_t index_shift{};
  int16_t xmin_fixed{};
  int16_t ymin_fixed{};
  uint32_t mm_addr_coords{};
  uint32_t mm_addr_features{};
  uint32_t mm_addr_grid{};
  uint16_t memcopy_size{};
  uint8_t struct_padding[8]{}; // pad structure to 32 byte
  COMMAND_SEGMENT_TYPE type{COMMAND_SEGMENT_TYPE::SCATTER_CMD};

    const char* to_char() const {
      static char buf[1024];
      sprintf(buf, "index_shift %i, " "xmin_fixed %i, " "ymin_fixed %i"
              "mm_addr_coords %x" "mm_addr_features %x" "memcopy_size %i",
             index_shift, xmin_fixed, ymin_fixed, mm_addr_coords, mm_addr_features, memcopy_size);
      return buf;
    }

    bool equals(const COMMAND_SCATTER &ref) const {
      bool equal = true;
      equal &= (ref.index_shift == index_shift);
      equal &= (ref.xmin_fixed == xmin_fixed);
      equal &= (ref.ymin_fixed == ymin_fixed);
      equal &= (ref.mm_addr_coords == mm_addr_coords);
      equal &= (ref.mm_addr_features == mm_addr_features);
      equal &= (ref.mm_addr_grid == mm_addr_grid);
      equal &= (ref.memcopy_size == memcopy_size);
      return equal;
    }
  };
  static_assert(sizeof(COMMAND_SCATTER) == 32, "Memory layout of packed struct");


  /**
   * COMMAND (Segment) storage
   *  either DMA or VPRO Command
   */

  struct  TYPE {
    uint8_t struct_padding[31]{};
    COMMAND_SEGMENT_TYPE type{};
  };

  // C++ does not allow polymorphism and inheritance for packed structs
  struct  COMMAND_SEGMENT {
    COMMAND_SEGMENT() : type{} {}; // no auto-generated constructor for unions
    union {
      TYPE type;
      COMMAND_VPRO vpro;
      COMMAND_DMA dma;
      COMMAND_DMA_LOOP dma_loop;
      COMMAND_SCATTER scatter;
    } ;

    // alignment in risc !
    // if COMMAND_SEGMENT size is 29 [28 data + 1 type]
    //      elements inside (accessed by LH/LW, as well for uint8_t)
    //      cause MEM-stage exception due to misaligned access
    //      array of segments need to align those to word-boundarys (COMMAND_Segment size multiple of 4-Byte)
    // dma_direct_command aligned 32 byte to reduce dcache complexity
    
    //    dma: 28 x 8-bit
    //    vpro: 20 x 8-bit

    const char* to_char() const {
      static char buf[4096];
      switch(type.type) {
      case COMMAND_SEGMENT_TYPE::DMA_CMD:
        if (dma.direction != loop)
            sprintf(buf, "%s, %s", ::to_char(type.type), dma.to_char() );
        else
            sprintf(buf, "%s, %s", ::to_char(type.type), dma_loop.to_char() );
        break;
      case COMMAND_SEGMENT_TYPE::VPRO_CMD:
        sprintf(buf, "%s, %s", ::to_char(type.type), vpro.to_char()); break;
      case COMMAND_SEGMENT_TYPE::DMA_BLOCK:
        sprintf(buf, "%s, size %s", ::to_char(type.type), dma.unit_mask_to_char()); break;
      default:
        sprintf(buf, "%s"  , ::to_char(type.type)                ); break;
      }
      return buf;
    }

    bool equals(const COMMAND_SEGMENT &ref) const {
      // this is ugly, but memcmp might fail due to padding
      bool equal = (ref.type.type == type.type);
      if (type.type == COMMAND_SEGMENT_TYPE::DMA_CMD)
        return equal && dma.equals(ref.dma);
      if (type.type == COMMAND_SEGMENT_TYPE::VPRO_CMD)
        return equal && vpro.equals(ref.vpro);
      return equal;
    }
  };
  static_assert(sizeof(COMMAND_SEGMENT) == 32, "Memory layout of packed struct");


  /**
   * LAYER storage
   */
  struct  PAD_REDUCED {
    int32_t top{};
    int32_t left{};
    int32_t bottom{};
    int32_t right{};
    int32_t value{};

    const char* to_char(const char *prefix = "") const {
      static char buf[1024];
      sprintf(buf, "%stop    %" PRId32 "" "%sleft   %" PRId32 "" "%sbottom %" PRId32 "" "%sright  %" PRId32 "" "%svalue  %" PRId32 "",
              prefix, top,
              prefix, left,
              prefix, bottom,
              prefix, right,
              prefix, value);
      return buf;
    }

  };
  static_assert(sizeof(PAD_REDUCED) == 20, "Memory layout of packed struct");

  struct  MM_IMAGE {
    uint32_t mm_base{}; // byte address
    uint32_t x{}; // number of payload elements per row
    uint32_t y{}; // number of payload elements per column
    uint32_t y_stride{}; // memory distance of two elements along dimension y
    uint32_t channels{};

    const char* to_char(const char *prefix = "") const {
      static char buf[1024];
      sprintf(buf, "%smm_base  0x%08" PRIx32 "" "%sx        %10" PRId32 "" "%sy        %10" PRId32 "" "%sy_stride %10" PRId32 "" "%schannels %10" PRId32 "",
              prefix, mm_base,
              prefix, x,
              prefix, y,
              prefix, y_stride, //x_postgap,
              prefix, channels);
      return buf;
    }

  };
  static_assert(sizeof(MM_IMAGE) == 20, "Memory layout of packed struct");
  
  // variable length list of COMMAND_SEGMENTS included at end of struct
  struct  LAYER {
    uint16_t in_channels{};
    uint16_t out_channels{};
    uint16_t number{};
    LAYERTYPE type{};
    uint8_t dummy1{}; // align following uint16 to 16 bit

    uint16_t stride{};
    uint16_t kernel_length{};
    uint16_t seg_out_w{};
    uint16_t seg_out_h{};
    uint16_t seg_in_w{};
    uint16_t seg_in_h{};

    int16_t conv_result_shift_right{};
    int16_t relu_6_shift_left{};
    int16_t alpha_mulh_shift_right{}; // 2 bytes
    int16_t bias_shift_right{};
    int16_t store_shift_right{};
    int16_t residual_1_left_shift{};
    int16_t residual_0_left_shift{};
    int16_t residual_1_right_shift{};
    int16_t residual_0_right_shift{};
    uint16_t pool_stride{};

    ACTIVATION activation{NO_ACTIVATION};
    uint8_t dummy2{}; // align following uint16 to 16 bit
    uint16_t alpha{}; // 4 bytes?
    PAD_REDUCED pad{}; // configure DMA unit per layer; COMMAND_DMA.pad_X switches padding on/off per transfer

    uint16_t axis{};
    uint16_t dynamic_shape{};
    uint16_t block_size{};

    MM_IMAGE input{}; // debug only, not used by runtime
    MM_IMAGE output{}; // debug only, not used by runtime

    int32_t command_segments_count{};

    uint8_t align_filler[12];   // to set command_segment list 32-byte aligned...

    COMMAND_SEGMENT command_segments[];
    
    //    uint32_t num_segments{};  // Removed. together with boundary ext see below
    //    uint8_t align_pad[4]{}; // to match 128-bit / 8 byte boundary for transfer with uemu...

    const char* to_char(bool legacy_compatibility = false) const {
      static char buf[4096];
      int offs = sprintf(buf,
              "in_channels             %d\n"
              "out_channels            %d\n"
              "number                  %d\n"
              "type                    %s\n"
              "stride                  %d\n"
              "kernel_length           %d\n"
              "seg_out_w               %d\n"
              "seg_out_h               %d\n"
              "seg_in_w                %d\n"
              "seg_in_h                %d\n"
              "conv_result_shift_right %d\n"
              "relu_6_shift_left       %d\n"
              "bias_shift_right        %d\n"
              "store_shift_right       %d\n"
              "residual_1_left_shift   %d\n"
              "residual_0_left_shift   %d\n"
              "pool_stride             %d\n"
              "activation              %s\n"
              "pad   : %s\n"
              "axis : %d\n"
              "dynamic_shape %d\n"
              "input : %s\n",
              in_channels,
              out_channels,
              number,
              ::to_char(type),
              stride,
              kernel_length,
              seg_out_w,
              seg_out_h,
              seg_in_w,
              seg_in_h,
              conv_result_shift_right,
              relu_6_shift_left,
              bias_shift_right,
              store_shift_right,
              residual_1_left_shift,
              residual_0_left_shift,
              pool_stride,
              ::to_char(activation),
              pad.to_char("  "),
              axis,
              dynamic_shape,
              input.to_char("  "));
      assert(offs >= 0);
      offs += sprintf(buf+offs, "output: %s\n", output.to_char("  "));
      assert(offs >= 0);
      if (!legacy_compatibility) {
        offs += sprintf(buf+offs, "command_segments_count  %d\n", command_segments_count);
        assert(offs >= 0);
      }
      return buf;
    }

  };
  static_assert(sizeof(LAYER) % 32 == 0, "Memory layout of packed struct needs to be 32-byte aligned!");
  // END based on cnn_struct_reduced.h g9114dd8

  constexpr static uint32_t net_magicword = 0xf3f67a81;
  
  // policy: store offsets instead of absolute pointers: relative addressing enables data relocation and is host-independent
  // avoid pointers/offsets when possible, instantiate instead
  // FIXME add VPRO config to NET for sanity checking
  struct  NET { 
    uint32_t magicword{};
    uint32_t blobsize{};
    uint32_t reserved{};
    uint32_t layer_execlist_count{}; // number of entries in layer_execlist_offs
    uint32_t layer_execlist_offs{}; // ptr (offset relative to BIF_NET) to linear array of 32 bit layer indices to be executed
    uint32_t layer_count{};
    uint32_t bif_layer_offs[]; // variable number of elements at end of struct
  };

} // namespace BIF


#endif // BIF_H
