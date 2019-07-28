import serial
import argparse


data = ['1','1','1','1']
parser = argparse.ArgumentParser(description='manual to this script')
parser.add_argument("rw",type=str,default=None)
parser.add_argument("-command",type=str,default=None)
parser.add_argument("-data",type=str,default=None)

args = parser.parse_args()
RW = args.rw


ser = serial.Serial('/dev/ttyAMA0',1000000)
if ser.isOpen == False:
    ser.open()

if RW == 'w' :
    COM = int(args.command,16)
    DATA = int(args.data,16)
    com_H  = (COM>>8) &0xff
    com_L  = COM & 0xff
    data_H = (DATA>>8)&0xff
    data_L = DATA&0xff
    
    ser.write(chr(0x00))
    ser.write(chr(com_H))
    ser.write(chr(com_L))
    ser.write(chr(data_H))
    ser.write(chr(data_L))
	
    data = ser.read(2)
    for i in [0,1]:
		print " recevie safetyworld is ", hex(ord(data[i]))
        
    print "com_H=" ,hex(com_H) , "com_L=" ,hex(com_L) ,"data_H= ",hex(data_H) ,"data_L= " ,hex(data_L) 
		
elif RW == 'r' :
    COM = int(args.command,16)
    com_H  = (COM>>8) &0xff
    com_L  = COM & 0xff
    ser.write(chr(0x01))
    ser.write(chr(com_H))
    ser.write(chr(com_L))

    data = ser.read(4)
    for i in [0,1,2,3]:
		print " recevie safetyworld is ", hex(ord(data[i]))
    print "com_H=" ,hex(com_H) , "com_L=" ,hex(com_L)     
		
