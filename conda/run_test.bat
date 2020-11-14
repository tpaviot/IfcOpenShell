cd ..\work\test

echo Test import
python -c "import ifcopenshell;import ifcopenshell.geom"

echo Run unittestts
python tests.py

echo Test IfcConvert
IfcConvert .\input\tesselated_faceset.ifc
IfcConvert .\input\revit2011_wall1.ifc

echo Test ifccsv.py
cd ..\src\ifccsv

python ifccsv.py -i ..\..\test\input\acad2010_walls.ifc -q ".IfcElement" -a "Name" "Description" --export -c out1.csv
python ifccsv.py -i ..\..\test\input\TestModel_IFC4Add2.ifc -q ".IfcElement" -a "Name" "Description" --export -c out2.csv
