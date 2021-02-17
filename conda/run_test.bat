rem cd ..\work\test

rem echo Test import
rem python -c "import ifcopenshell;import ifcopenshell.geom"

rem echo Run unittestts
rem python tests.py

rem echo Test IfcConvert
rem IfcConvert .\input\tesselated_faceset.ifc
rem IfcConvert .\input\revit2011_wall1.ifc

rem echo Test ifccsv.py
rem cd ..\src\ifccsv

rem python ifccsv.py -i ..\..\test\input\acad2010_walls.ifc -q ".IfcElement" -a "Name" "Description" --export -c out1.csv
rem python ifccsv.py -i ..\..\test\input\TestModel_IFC4Add2.ifc -q ".IfcElement" -a "Name" "Description" --export -c out2.csv
