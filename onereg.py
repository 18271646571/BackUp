import os 
import smbus
import time
from addressname import *
import argparse

parser = argparse.ArgumentParser(description='manual to this script')
parser.add_argument("rw",type=str,default=None)
parser.add_argument("-address",type=str,default=None)
parser.add_argument("-data",type=str,default=None)
args = parser.parse_args()
RW = args.rw


def write(address,slaveadd,data):
    addressH = (slaveadd >> 8 ) & 0xff
    addressL = slaveadd  & 0xff
    os.system("i2cset -y 1 %d %d %d %d  i" % ( address,addressH,addressL,data) )

def write_16(address,slaveadd,data):
    addressH = (slaveadd >> 8 ) & 0xff
    addressL = slaveadd  & 0xff
        
    dataH = (data >>8 ) & 0xff
    dataL = data & 0xff

    os.system("i2cset -y 1 %d %d %d %d %d  i" % ( address,addressH,addressL,dataH, dataL) )

def read(bus,address,slaveadd):
    addressH = (slaveadd >> 8 ) & 0xff
    addressL = slaveadd  & 0xff
    bus.write_byte_data(address,addressH,addressL)
    return bus.read_byte(address)


# pic_clk = 60MHz   mipi_clk = 600MHz   sys_clk = 48MHz ADC_clk = 240MHz
def PllControl():
    write(Cameradd, PLL_PLL18,0x05) # div/2.5
    write(Cameradd, PLL_PLL19,0x30) # 48x
    write(Cameradd, PLL_PLL1A,0x05) #sys div /10
    write(Cameradd, PLL_PLL1B,0x04) #adc div /2
    write(Cameradd, PLL_PLL1D,0x00)

    write(Cameradd, PLL_PLL1_PRE_PLL_DIV, 0x07)#div /2.5
    write(Cameradd, PLL_MULTIPLIER,0X3C) # 60X
    write(Cameradd, PLL_VT_SYS_CLK_DIV,0X01)
    write(Cameradd, PLL_VT_PIX_CLK_DIV,0X0A)#/10 
    write(Cameradd, PLL_PLL1_OP_PIX_CLK_DIV,0X04)


if RW == 'w' :
    Add = int(args.address,16)
    data = int(args.data,16)
    write(Cameradd,Add,data)
    print " write address is ",hex(Add) ,"write data is ",hex(data) 
elif RW == 'r' :
    dat = int(args.address,16)
    bus  = smbus.SMBus(1)
    print( hex( read(bus,0X36,dat)) )
   