import ifcopenshell


class Usecase:
    def __init__(self, file, settings=None):
        self.file = file
        self.settings = {"opening": None, "element": None}
        for key, value in settings.items():
            self.settings[key] = value

    def execute(self):
        self.file.create_entity("IfcRelVoidsElement", **{
            "GlobalId": ifcopenshell.guid.new(),
            "RelatingBuildingElement": self.settings["element"],
            "RelatedOpeningElement": self.settings["opening"]
        })
