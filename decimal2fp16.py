import numpy as np
from decimal import Decimal, getcontext

getcontext().prec = 16  # Set the precision to match fp16 (16 bits)
getcontext().rounding = 'ROUND_HALF_EVEN'  # Use "round to nearest, ties to even" rounding

def convert_to_fp16_binary(value):
    # Convert the decimal value to half-precision (fp16)
    fp16_value = Decimal(value)

    # Convert the fp16 value to its binary representation without the '0b' prefix
    binary_representation = bin(np.float16(fp16_value).view('H'))[2:].zfill(16)

    return binary_representation

# opening the file in read mode 
input_file = open("decimal_multiplication_result.txt", "r") 
inputs = input_file.read() 
input_list = inputs.split('\n')
input_file.close()

fp16_multiplication_result_file = open("fp16_multiplication_result.txt", "w") 
fp16_multiplication_result_file.write('')
fp16_multiplication_result_file.close()
fp16_multiplication_result_file = open("fp16_multiplication_result.txt", "a") 

for input in input_list:
    fp16 = convert_to_fp16_binary(input)
    fp16_multiplication_result_file.write(str(fp16)+'\n')

fp16_multiplication_result_file.close()