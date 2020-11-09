import glob
import os
import time

all_ifc_file = glob.glob(os.path.join('.', 'input', '*.ifc'))

for ifc_tst_file in all_ifc_file:
	os.system('IfcConvert %s' % ifc_tst_file)
