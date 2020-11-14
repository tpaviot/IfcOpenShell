#!/bin/bash
cd ../work/test

echo -e "Test import"
python -c "import ifcopenshell;import ifcopenshell.geom;print('imports ok')"

echo -e "Run unittestts"
python tests.py

echo -e "Test IfcConvert"
IfcConvert ./input/tesselated_faceset.ifc
IfcConvert ./input/revit2011_wall1.ifc

echo -e "Test ifccsv.py"
cd ../src/ifccsv

./ifccsv.py -i ../../test/input/acad2010_walls.ifc -q ".IfcElement" -a "Name" "Description" --export -c out1.csv
./ifccsv.py -i ../../test/input/TestModel_IFC4Add2.ifc -q ".IfcElement" -a "Name" "Description" --export -c out2.csv
