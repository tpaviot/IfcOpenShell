cd ..\work\test

echo Test import
python -c "import ifcopenshell;import ifcopenshell.geom"

echo Run unittestts
python tests.py

echo Test IfcConvert
IfcConvert .\input\tesselated_faceset.ifc
IfcConvert .\input\revit2011_wall1.ifc
