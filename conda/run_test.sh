#!/bin/bash
cd ../work/test

echo -e "Test import"
python -c "import ifcopenshell;import ifcopenshell.geom"

echo -e "Run unittestts"
python tests.py

echo -e "Test IfcConvert"
IfcConvert ./input/tesselated_faceset.ifc
IfcConvert ./input/revit2011_wall1.ifc
