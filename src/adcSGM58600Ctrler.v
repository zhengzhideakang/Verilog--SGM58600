/*
 * @Author       : Xu Dakang
 * @Email        : XudaKang_up@qq.com
 * @Date         : 2021-05-25 15:22:30
 * @LastEditors  : Xu Xiaokang
 * @LastEditTime : 2024-09-26 23:37:40
 * @Filename     :
 * @Description  :
*/

/*
! 模块功能: 与ADC芯片SGM58600（对标TI的ADS1255）对接，控制其放大倍数，输出速率等信息，接收其输出并转为24位数据
* 思路:
  1.
~ 使用
  1.输入clk必须为7.69MHz
  2.模块工作于连续读模式
  3.采样率通过DRATE设定
*/

`default_nettype none

module adcSGM58600Ctrler
#(
  parameter STATUS = 8'b0000_0100, // 打开自动校准
  parameter MUX    = 8'b0001_0000, // 前四位设定通道P, 后四位设定通道N, AIN1为P, AIN0为N,
  parameter ADCON  = 8'b0000_0001, // PGA = 2^0 = 1
  parameter DRATE  = 8'b1111_0000  // 对应30000SPS
)(
  output reg  [23 : 0]  adc_dout_24b,
  output reg            adc_dout_24b_valid,

  // SPI接口
  output wire         adc_cs_n,
  output wire         adc_sclk,
  output reg          adc_din,
  input  wire         adc_dout,
  input  wire         adc_drdy_n,

  output wire         adc_sync_n,
  output wire         adc_rst_n,
  output wire         adc_clk,

  input  wire         clk,    // 7.69MHz
  input  wire         rstn
);


//< 生成adc时钟 ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
assign adc_clk = clk;
//< 生成adc时钟 ------------------------------------------------------------


//> 边沿检测 ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
reg adc_drdy_n_r1;
always @(posedge adc_clk) begin
  adc_drdy_n_r1 <= adc_drdy_n;
end

wire adc_drdy_n_nedge = ~adc_drdy_n && adc_drdy_n_r1;
wire adc_drdy_n_pedge = adc_drdy_n && ~adc_drdy_n_r1;
//> 边沿检测 ------------------------------------------------------------


//< 使能 同步 复位 ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
assign adc_cs_n   = 1'b0; // 使能ADC
assign adc_sync_n = 1'b1; // 不使用同步
assign adc_rst_n  = rstn; // 模块复位时ADC也复位
//< 使能 同步 复位 ------------------------------------------------------------


//> 状态机定义与状态跳转 ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
// * 状态定义 初始态 -> 写寄存器 -> 发送连续读命令 -> 连续读数据
localparam IDLE                     = 4'b0001;
localparam WRITE_REG                = 4'b0010;
localparam SEND_CONTINUOUS_READ_CMD = 4'b0100;
localparam CONTINUOUS_READ_DATA     = 4'b1000;

// * 初始态与状态跳转
reg [3 : 0] state, next;
always @(posedge adc_clk) begin
  if (~rstn)
    state <= IDLE;
  else
    state <= next;
end

wire write_reg_finish; // 写寄存器命令完成指示信号
wire rdatac_cmd_clk_space_finish; // 连续读命令发送后, 等待至少50个clk完成, 可以开始读输出数据了
// * 跳转到下一个状态的条件
always @(*) begin
  next = state;
  case (1'b1)
    state[0]: if (adc_drdy_n_nedge)                     next = WRITE_REG;
    state[1]: if (adc_drdy_n_nedge && write_reg_finish) next = SEND_CONTINUOUS_READ_CMD;
    state[2]: if (rdatac_cmd_clk_space_finish)          next = CONTINUOUS_READ_DATA;
    state[3]: ;
    default: next = IDLE;
  endcase
end
//> 状态机定义与状态跳转 ------------------------------------------------------------


//< 生成串行时钟 ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
reg adc_sclk_en;

reg [1:0] adc_sclk_cnt;
always @(posedge adc_clk) begin
  if (adc_sclk_en)
    adc_sclk_cnt <= adc_sclk_cnt + 1'b1;
  else if (adc_sclk_cnt == 2'b10) //! 保证sclk的占空比始终为0.5
    adc_sclk_cnt <= adc_sclk_cnt + 1'b1;
  else
    adc_sclk_cnt <= 'd0;
end

assign adc_sclk = adc_sclk_cnt[1]; // 2'b10, 2'b11为高

wire adc_sclk_pedge = (adc_sclk_cnt == 2'b10);

localparam [5 : 0] STATE_1_SCLK_CNT_MAX = 16 + 32;
reg [5 : 0] state_1_sclk_pedge_cnt;
always @(posedge adc_clk) begin
  if (~rstn)
    state_1_sclk_pedge_cnt <= 'd0;
  else
    case (1'b1)
      state[1]: if (adc_sclk_pedge && state_1_sclk_pedge_cnt < STATE_1_SCLK_CNT_MAX)
                  state_1_sclk_pedge_cnt <= state_1_sclk_pedge_cnt + 1'b1;
      default: ;
    endcase
end

assign write_reg_finish = (state_1_sclk_pedge_cnt == STATE_1_SCLK_CNT_MAX) ? 1'b1 : 1'b0;

localparam [3 : 0] RDATAC_CMD_SCLK_CNT_MAX = 8;
reg [3 : 0] rdatac_cmd_sclk_pedge_cnt;
always @(posedge adc_clk) begin
  if (~rstn)
    rdatac_cmd_sclk_pedge_cnt <= 'd0;
  else
    case (1'b1)
      state[2]: if (adc_sclk_pedge && rdatac_cmd_sclk_pedge_cnt < RDATAC_CMD_SCLK_CNT_MAX)
                  rdatac_cmd_sclk_pedge_cnt <= rdatac_cmd_sclk_pedge_cnt + 1'b1;
      default: ;
    endcase
end

wire rdatac_cmd_finish = (rdatac_cmd_sclk_pedge_cnt == RDATAC_CMD_SCLK_CNT_MAX);

localparam RDATAC_CMD_CLK_SPACE_CNT_MAX = 50; // 连续读命令发出后,需要至少间隔50个clk周期再使能sclk
reg [5 : 0] rdatac_cmd_clk_space_cnt;
always @(posedge adc_clk) begin
  if (~rstn)
    rdatac_cmd_clk_space_cnt <= 'd0;
  else
    case (1'b1)
      state[2]: if (rdatac_cmd_finish && rdatac_cmd_clk_space_cnt < RDATAC_CMD_CLK_SPACE_CNT_MAX)
                  rdatac_cmd_clk_space_cnt <= rdatac_cmd_clk_space_cnt + 1'b1;
      default: ;
    endcase
end

assign rdatac_cmd_clk_space_finish = (rdatac_cmd_clk_space_cnt == RDATAC_CMD_CLK_SPACE_CNT_MAX);

always @(*) begin
  adc_sclk_en = 1'b0;
  case (1'b1)
    state[1]: if (~write_reg_finish)                 adc_sclk_en = 1'b1;
    state[2]: if (~adc_drdy_n && ~rdatac_cmd_finish) adc_sclk_en = 1'b1;
    state[3]: if (~adc_drdy_n)                       adc_sclk_en = 1'b1;
    default: ;
  endcase
end
//< 生成串行时钟 ------------------------------------------------------------


//> 写寄存器 ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
/*
  先写第一个寄存器地址，然后往每个寄存器写值
*/

// 写操作命令
localparam WREG = 4'b0101;
// 寄存器地址 MUX_ADDR = 4'h1; ADCON_ADDR = 4'h2; DRATE_ADDR  = 4'h3;
localparam STATUS_ADDR = 4'h0;

localparam [15 : 0] WRITE_REG_CMD = {WREG, STATUS_ADDR, 4'h0, 4'h3};
localparam [31 : 0] ADC_DIN_VALUE = {STATUS, MUX, ADCON, DRATE};

reg [16+32 : 0] adc_din_wreg;
always @(posedge adc_clk) begin
  if (~rstn)
    adc_din_wreg <= {1'b0, WRITE_REG_CMD, ADC_DIN_VALUE}; // 最高位会被移出, 未输入到ADC
  else
    case (1'b1)
      state[1]: if (adc_sclk_pedge)
                  adc_din_wreg <= adc_din_wreg << 1;
      default: ;
    endcase
end
//> 写寄存器 ------------------------------------------------------------


//< 发送连续读命令 ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
localparam RDATAC = 8'b0000_0011;
reg [8 : 0] adc_din_send_continuous_read_cmd;
always @(posedge adc_clk) begin
  if (~rstn)
    adc_din_send_continuous_read_cmd <= {1'b0, RDATAC}; // 最高位会被移出, 未输入到ADC
  else
    case (1'b1)
      state[2]: if (adc_sclk_pedge)
                  adc_din_send_continuous_read_cmd <= adc_din_send_continuous_read_cmd << 1;
      default: ;
    endcase
end
//< 发送连续读命令 ------------------------------------------------------------


//> ADC数据输入 ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
always @(*) begin
  adc_din = 1'b0;
  case (1'b1)
    state[1]: adc_din = adc_din_wreg[16 + 32];
    state[2]: adc_din = adc_din_send_continuous_read_cmd[8];
    default: ;
  endcase
end
//> ADC数据输入 ------------------------------------------------------------


//< 连续读数据 ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
reg adc_sclk_pedge_r1; // sclk上升沿偏移一个时钟周期, 等待dout稳定
always @(posedge adc_clk) begin
  adc_sclk_pedge_r1 <= adc_sclk_pedge;
end

reg [23 : 0] adc_dout_24b_temp;
always @(posedge adc_clk) begin
  case (1'b1)
    state[3]: if (adc_sclk_pedge_r1)
                adc_dout_24b_temp <= {adc_dout_24b_temp[22 : 0], adc_dout};
    default: adc_dout_24b_temp <= 'd0;
  endcase
end

always @(posedge adc_clk) begin
  if (~rstn)
    adc_dout_24b <= 'd0;
  else
    case (1'b1)
      state[3]: if (adc_drdy_n_pedge) adc_dout_24b <= adc_dout_24b_temp;
      default: ;
    endcase
end

always @(posedge adc_clk) begin
  case (1'b1)
    state[3]: if (adc_drdy_n_pedge) adc_dout_24b_valid <= 1'b1;
              else                  adc_dout_24b_valid <= 1'b0;
    default: adc_dout_24b_valid <= 1'b0;
  endcase
end
//< 连续读数据 ------------------------------------------------------------


endmodule
`resetall