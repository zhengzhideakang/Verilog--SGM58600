# Verilog功能模块--ADC SGM58600驱动

Gitee与Github同步：

[Verilog功能模块--ADC SGM58600驱动: Verilog功能模块--ADC SGM58600驱动 (gitee.com)](https://gitee.com/xuxiaokang/verilog-functional-module--SGM58600)

[zhengzhideakang/Verilog--SGM58600: Verilog功能模块——ADC SGM58600驱动 (github.com)](https://github.com/zhengzhideakang/Verilog--SGM58600)

## 简介
与ADC芯片SGM58600（对标TI的ADS1255）对接，控制其放大倍数，输出速率等信息，接收其输出并转为24位数据。

3、4年前编写的模块，后续并没有更多机会使用SGM58600，故此仓库应该很长时间不会更新。

## 模块框图

![adcSGM58600Ctrler](https://picgo-dakang.oss-cn-hangzhou.aliyuncs.com/img/adcSGM58600Ctrler.svg)

使用注意：

1. 输入clk必须为7.69MHz

2. 模块工作于连续读模式

3. 采样率通过DRATE设定
