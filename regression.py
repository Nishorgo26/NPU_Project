import subprocess
import os
import time
import re
import argparse
from pathlib import Path
from decimal import *

getcontext().prec = 4

program_start = time.time()

def custom_print(message):
    print(message)  # Print to console
    report_file.write(message + '\n') 

#---- Script settings
progess_mode        = False
nearest_threshold   = 0.2
    
#---- Check if test directory exists

test_dir = Path("./test")
if not test_dir.is_dir():
    print("Error: Test directory not found")
    quit()

#---- Load the expected results

# expected_result_file = open("./test/test_lables.txt", "r")
# expected_result = expected_result_file.read()
# expected_result_list = expected_result.split('\n')
# expected_result_file.close()

#---- Load sample files

sample_files = os.listdir("./test/samples")

parser = argparse.ArgumentParser(description="Process lines from a file within a specified range.")
parser.add_argument("-start", type=int, help="Start line number (default: 1)")
parser.add_argument("-stop", type=int, help="Stop line number")
parser.add_argument("-max", type=int, default=10, help="Max sample files to analyze")
args = parser.parse_args()

start_line = args.start
end_line = args.stop 
max_line = args.max 

if start_line is not None:
    if end_line is None:
        end_line = start_line + max_line - 1
else:
    start_line = 1 
    if end_line is None:
        end_line = start_line + max_line - 1

if end_line > len(sample_files):
    end_line = len(sample_files)

if start_line > end_line:
    print ("RANGE IS INVALID")
    exit ()

start_line = start_line - 1
end_line   = end_line   
max_line   = max_line   
#---- Remove regression report files
if os.path.isfile("regression_report.txt"):
    os.remove("regression_report.txt")

report_file = open("regression_report.txt", 'a')

def seconds_to_hms(seconds):
    # Calculate hours, minutes, and remaining seconds
    hours, remainder = divmod(seconds, 3600)
    minutes, seconds = divmod(remainder, 60)
    h_f = "{:.2f}".format(hours)
    m_f = "{:.2f}".format(minutes)
    s_f = "{:.2f}".format(seconds)
    return h_f, m_f, s_f

def extract_last_number(input_string):
    # Use regular expression to find the last number in the string
    matches = re.findall(r'\d+', input_string)

    # Check if there are any matches
    if matches:
        # Return the last match (last number found)
        return int(matches[-1])
    else:
        # Return an appropriate value (e.g., 0) if no number is found
        return 0

#---- Print Header
custom_print("\t\t\t\t\t\t+---------------------------------------------------+")
custom_print("\t\t\t\t\t\t|   Total Sampling : "+ str(end_line-start_line))
custom_print("\t\t\t\t\t\t|   Starting file  : "+ sample_files[start_line]+"  |")
custom_print("\t\t\t\t\t\t|   Endind   file  : "+ sample_files[end_line-1]+"  |")
custom_print("\t\t\t\t\t\t+---------------------------------------------------+")
custom_print("                        \t+" + "-"*10  + "+" + "-"*15 + "+" + "-"*15 + "+"    + "-"*(len(str(end_line))*2+9) + "+"           + "-"*31        + "+"+"-"*10+"+"+ "-"*15  + "+" + "-"*13 + "+" + "-"*15  + "+" )
custom_print("                        \t|          |               | Total Pass    |  " +  "   " + " "*(len(str(end_line))*2+4) + "|                               | Expected | Highest       | Total close | Total Close   |" )
custom_print("                        \t| Result   | Pass:Fail     | Percentage    | SL" + " "*(len(str(end_line))*2+6) + "| File name                     | Value    | Value         | Values      | Values        |" )
custom_print("                        \t+" + "-"*10  + "+" + "-"*15 + "+" + "-"*15 +  "+"    + "-"*(len(str(end_line))*2+9) + "+"           + "-"*31        + "+"+"-"*10+"+"+ "-"*15  + "+" + "-"*13 + "+" + "-"*15  + "+" )

pass_array  = [0] * 10
fail_array  = [0] * 10
total_array = [0] * 10

#---- Run Regression

i = start_line
fail_count = 0
pass_count = 0
ignore_count = 0
total_store_time = 0

for ip in range(start_line,end_line):
    loop_starts = time.time()
    input_file = sample_files[ip]
    #---- Break if end_line reached
    if i == end_line:
        break
    
    if(progess_mode): os.system('cls' if os.name == 'nt' else 'clear')
    
    #---- Remove previous output files
    if os.path.isfile("fifo_output_float.txt"):
        os.remove("fifo_output_float.txt")
    if os.path.isfile("fifo_output.txt"):
        os.remove("fifo_output.txt")
    
    #---- Modify dofile and pass sample file
    with open('project/regression.do', 'r') as file:
        data = file.readlines()
        file.close()
    
    last_number = extract_last_number(input_file)

    data[2] = "vsim -quiet -c work.testbench +INPUTFILE=" + input_file + '\n'

    with open('project/regression.do', 'w') as file:
        file.writelines( data )
    file.close()

    #---- Run VSIM Simulation
    os.system('cmd /c "vsim -c -do project/regression.do" > NUL')
    # os.system('cmd /c "vsim -c -do project/regression.do"')
    
    #---- Convert binary output to decimal
    subprocess.run(["python", "fifo_bin_2_float.py"])

    #---- Get the decimal output report
    with open('fifo_output_float.txt', 'r') as output_file:
        if not output_file.read(1):
            output_file.close()
            fail_count = fail_count + 1
            ignore_count = ignore_count + 1
            result = "IG-NO-R-ED"
        
        else:
            output_file.seek(0)
            outputs = output_file.readlines()
            output_file.close()
            # for value in outputs:
            #     output_list.push(int(value)*100)
            # output_list = outputs.split('\n')
            
            found_number = str(outputs.index(max(outputs)))
            other_values = [idx for idx, val in enumerate(outputs) if (float(val) > 0 and float(val) != float(max(outputs)))]

            # other_values_percentage = [['{} ({}%)'.format(index, item)] for index, item in enumerate(other_values)]

            # print("Found: " + found_number)
            if str(last_number) == found_number:
                result = "  PASSED"
                pass_count = pass_count + 1
            else:
                result = "- FAILED"
                fail_count = fail_count + 1

        for num in range(10):
            if last_number == num:
                total_array[num] = + total_array[num] + 1
                if result == "  PASSED":
                    pass_array[num] = pass_array[num] + 1
                else:
                    fail_array[num] = fail_array[num] + 1

        
        percentage = (pass_count/(pass_count + fail_count))*100
        formatted_percentage = "{:.2f}".format(percentage)
        now = time.time()
        loop_time = now - loop_starts
        total_store_time = total_store_time + loop_time
        hours, minutes, seconds = seconds_to_hms(total_store_time)
        custom_print(str(hours) + "h " + str(minutes) + "m " + str(seconds) + "s " + " \t| " + str(loop_time)[0 : 4] + "s " + "| " + result + " | " + str(pass_count).zfill(len(str(end_line))) + ":" + str(fail_count).zfill(len(str(end_line))) + "       |   " + str(formatted_percentage).zfill(6) + "%     | "+ "["+str(i+1).zfill(len(str(end_line)))+" / "+ str(end_line) +"]   | " + input_file + " | " + " "*4 + str(last_number) + " "*4 + "| " +str(found_number) + " ( " + str(Decimal(max(outputs).replace("\n", ""))*100) + "% )  | " + str(len(other_values)) + "           | " + str(other_values))
        i = i + 1

#---- Close the report file
# custom_print("                        +" + "-"*10 + "+"    + "-"*(len(str(end_line))*2+7) + "+"           + "-"*31        + "+"+"-"*10+"+"+ "-"*15  + "+" + "-"*13 + "+" + "-"*15  + "+")

program_end = time.time()

custom_print("\n\tTotal Sampled    : " + str(pass_count+fail_count+ignore_count))
custom_print("\tTotal Passed     : " + str(pass_count))
custom_print("\tTotal Failed     : " + str(fail_count))
custom_print("\tTotal Ignored    : " + str(ignore_count))
custom_print("\tPass percentage  : " + str((formatted_percentage) + "%"))
custom_print("\tTotal time       : " + str(hours) + "h " + str(minutes) + "m " + str(seconds) + "s\n")

for numbr in range(10):
    custom_print("\t"+str(numbr)+"'s Total Image: " + str(total_array[numbr]) +"\t| Total Passed: "+str(pass_array[numbr]) +"\t| Total Failed: "+str(fail_array[numbr]))
custom_print("----------------------------------------------------------------------------------------------------------------------------------------------------------\n")
# custom_print("\t IMAGE OF 0 :")