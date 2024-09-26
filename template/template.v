/*
 * @Author       : Xu Xiaokang
 * @Email        :
 * @Date         : 2024-09-14 11:40:11
 * @LastEditors  : Xu Xiaokang
 * @LastEditTime : 2024-09-26 23:52:56
 * @Filename     :
 * @Description  :
*/

/*
! 模块功能: adcSGM58600Ctrler实例化参考
*/

adcSGM58600Ctrler #(
  .STATUS (STATUS),
  .MUX    (MUX   ),
  .ADCON  (ADCON ),
  .DRATE  (DRATE )
) adcSGM58600Ctrler_u0 (
  .adc_dout_24b       (adc_dout_24b      ),
  .adc_dout_24b_valid (adc_dout_24b_valid),
  .adc_cs_n           (adc_cs_n          ),
  .adc_sclk           (adc_sclk          ),
  .adc_din            (adc_din           ),
  .adc_dout           (adc_dout          ),
  .adc_drdy_n         (adc_drdy_n        ),
  .adc_sync_n         (adc_sync_n        ),
  .adc_rst_n          (adc_rst_n         ),
  .adc_clk            (adc_clk           ),
  .clk                (clk               ),
  .rstn               (rstn              )
);