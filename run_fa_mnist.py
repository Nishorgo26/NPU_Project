import os
import argparse

parser = argparse.ArgumentParser(prog='Run.py', description='Specify range', epilog=':)')
parser.add_argument("-start", type=int, help="Specify starting image number")
parser.add_argument("-stop", type=int, help="Specify last image number")
parser.add_argument("-debug", action='store_true', help="Use for enabling debug mode")

args = parser.parse_args()

start_image = args.start
end_image = args.stop
debug_val = args.debug

if debug_val:
	os.system('vsim -c work.tb_fm_seq_fa_mnist -do "run -all" +START=' + str(start_image) + ' +STOP=' + str(end_image) + ' +define+DEBUG_MODE');
else:
	os.system('vsim -c work.tb_fm_seq_fa_mnist -do "run -all" +START=' + str(start_image) + ' +STOP=' + str(end_image));
