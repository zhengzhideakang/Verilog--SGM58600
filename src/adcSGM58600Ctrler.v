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
! ģ�鹦��: ��ADCоƬSGM58600���Ա�TI��ADS1255���Խӣ�������Ŵ�����������ʵ���Ϣ�������������תΪ24λ����
* ˼·:
  1.
~ ʹ��
  1.����clk����Ϊ7.69MHz
  2.ģ�鹤����������ģʽ
  3.������ͨ��DRATE�趨
*/

`default_nettype none

module adcSGM58600Ctrler
#(
  parameter STATUS = 8'b0000_0100, // ���Զ�У׼
  parameter MUX    = 8'b0001_0000, // ǰ��λ�趨ͨ��P, ����λ�趨ͨ��N, AIN1ΪP, AIN0ΪN,
  parameter ADCON  = 8'b0000_0001, // PGA = 2^0 = 1
  parameter DRATE  = 8'b1111_0000  // ��Ӧ30000SPS
)(
  output reg  [23 : 0]  adc_dout_24b,
  output reg            adc_dout_24b_valid,

  // SPI�ӿ�
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


//< ����adcʱ�� ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
assign adc_clk = clk;
//< ����adcʱ�� ------------------------------------------------------------


//> ���ؼ�� ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
reg adc_drdy_n_r1;
always @(posedge adc_clk) begin
  adc_drdy_n_r1 <= adc_drdy_n;
end

wire adc_drdy_n_nedge = ~adc_drdy_n && adc_drdy_n_r1;
wire adc_drdy_n_pedge = adc_drdy_n && ~adc_drdy_n_r1;
//> ���ؼ�� ------------------------------------------------------------


//< ʹ�� ͬ�� ��λ ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
assign adc_cs_n   = 1'b0; // ʹ��ADC
assign adc_sync_n = 1'b1; // ��ʹ��ͬ��
assign adc_rst_n  = rstn; // ģ�鸴λʱADCҲ��λ
//< ʹ�� ͬ�� ��λ ------------------------------------------------------------


//> ״̬��������״̬��ת ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
// * ״̬���� ��ʼ̬ -> д�Ĵ��� -> �������������� -> ����������
localparam IDLE                     = 4'b0001;
localparam WRITE_REG                = 4'b0010;
localparam SEND_CONTINUOUS_READ_CMD = 4'b0100;
localparam CONTINUOUS_READ_DATA     = 4'b1000;

// * ��ʼ̬��״̬��ת
reg [3 : 0] state, next;
always @(posedge adc_clk) begin
  if (~rstn)
    state <= IDLE;
  else
    state <= next;
end

wire write_reg_finish; // д�Ĵ����������ָʾ�ź�
wire rdatac_cmd_clk_space_finish; // ����������ͺ�, �ȴ�����50��clk���, ���Կ�ʼ�����������
// * ��ת����һ��״̬������
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
//> ״̬��������״̬��ת ------------------------------------------------------------


//< ���ɴ���ʱ�� ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
reg adc_sclk_en;

reg [1:0] adc_sclk_cnt;
always @(posedge adc_clk) begin
  if (adc_sclk_en)
    adc_sclk_cnt <= adc_sclk_cnt + 1'b1;
  else if (adc_sclk_cnt == 2'b10) //! ��֤sclk��ռ�ձ�ʼ��Ϊ0.5
    adc_sclk_cnt <= adc_sclk_cnt + 1'b1;
  else
    adc_sclk_cnt <= 'd0;
end

assign adc_sclk = adc_sclk_cnt[1]; // 2'b10, 2'b11Ϊ��

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

localparam RDATAC_CMD_CLK_SPACE_CNT_MAX = 50; // �������������,��Ҫ���ټ��50��clk������ʹ��sclk
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
//< ���ɴ���ʱ�� ------------------------------------------------------------


//> д�Ĵ��� ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
/*
  ��д��һ���Ĵ�����ַ��Ȼ����ÿ���Ĵ���дֵ
*/

// д��������
localparam WREG = 4'b0101;
// �Ĵ�����ַ MUX_ADDR = 4'h1; ADCON_ADDR = 4'h2; DRATE_ADDR  = 4'h3;
localparam STATUS_ADDR = 4'h0;

localparam [15 : 0] WRITE_REG_CMD = {WREG, STATUS_ADDR, 4'h0, 4'h3};
localparam [31 : 0] ADC_DIN_VALUE = {STATUS, MUX, ADCON, DRATE};

reg [16+32 : 0] adc_din_wreg;
always @(posedge adc_clk) begin
  if (~rstn)
    adc_din_wreg <= {1'b0, WRITE_REG_CMD, ADC_DIN_VALUE}; // ���λ�ᱻ�Ƴ�, δ���뵽ADC
  else
    case (1'b1)
      state[1]: if (adc_sclk_pedge)
                  adc_din_wreg <= adc_din_wreg << 1;
      default: ;
    endcase
end
//> д�Ĵ��� ------------------------------------------------------------


//< �������������� ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
localparam RDATAC = 8'b0000_0011;
reg [8 : 0] adc_din_send_continuous_read_cmd;
always @(posedge adc_clk) begin
  if (~rstn)
    adc_din_send_continuous_read_cmd <= {1'b0, RDATAC}; // ���λ�ᱻ�Ƴ�, δ���뵽ADC
  else
    case (1'b1)
      state[2]: if (adc_sclk_pedge)
                  adc_din_send_continuous_read_cmd <= adc_din_send_continuous_read_cmd << 1;
      default: ;
    endcase
end
//< �������������� ------------------------------------------------------------


//> ADC�������� ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
always @(*) begin
  adc_din = 1'b0;
  case (1'b1)
    state[1]: adc_din = adc_din_wreg[16 + 32];
    state[2]: adc_din = adc_din_send_continuous_read_cmd[8];
    default: ;
  endcase
end
//> ADC�������� ------------------------------------------------------------


//< ���������� ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
reg adc_sclk_pedge_r1; // sclk������ƫ��һ��ʱ������, �ȴ�dout�ȶ�
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
//< ���������� ------------------------------------------------------------


endmodule
`resetall