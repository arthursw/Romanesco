from mongoengine import *
import datetime

class Path(Document):
    planetX = DecimalField()
    planetY = DecimalField()
    box = PolygonField()
    points = LineStringField()
    rType = StringField(default='Path')
    owner = StringField()
    date = DateTimeField(default=datetime.datetime.now)
    lastUpdate = DateTimeField(default=datetime.datetime.now)
    object_type = StringField(default='brush')
    lock = StringField(default=None)
    # areas = ListField(ReferenceField('Area'))

    data = StringField(default='')

    meta = {
        'indexes': [[ ("planetX", 1), ("planetY", 1), ("points", "2dsphere") ]]
    }

class Box(Document):
    planetX = DecimalField()
    planetY = DecimalField()
    box = PolygonField()
    rType = StringField(default='Box')
    owner = StringField()
    date = DateTimeField(default=datetime.datetime.now)
    lastUpdate = DateTimeField(default=datetime.datetime.now)
    object_type = StringField()

    restrictedArea = BooleanField(default=False)
    disableToolbar = BooleanField(default=False)
    loadEntireArea = BooleanField(default=False)
    module = ReferenceField('Module')

    # deprecated: put in data
    # url = URLField(verify_exists=True, required=False)
    name = StringField()
    # message = StringField()
    # areas = ListField(ReferenceField('Area'))

    data = StringField(default='')

    meta = {
        'indexes': [ [ ("planetX", 1), ("planetY", 1), ("box", "2dsphere") ], [ ("name", 1) ] ]
    }

class AreaToUpdate(Document):
    planetX = DecimalField()
    planetY = DecimalField()
    box = PolygonField()

    rType = StringField(default='AreaToUpdate')
    # areas = ListField(ReferenceField('Area'))

    meta = {
        'indexes': [[ ("planetX", 1), ("planetY", 1), ("box", "2dsphere") ]]
    }

class Div(Document):
    planetX = DecimalField()
    planetY = DecimalField()
    box = PolygonField()
    rType = StringField(default='Div')
    owner = StringField()
    date = DateTimeField(default=datetime.datetime.now)
    lastUpdate = DateTimeField(default=datetime.datetime.now)
    object_type = StringField()
    lock = StringField(default=None)

    # deprecated: put in data
    url = StringField(required=False)
    message = StringField()

    # areas = ListField(ReferenceField('Area'))

    data = StringField(default='')

    meta = {
        'indexes': [[ ("planetX", 1), ("planetY", 1), ("box", "2dsphere") ]]
    }

class Tool(Document):
    name = StringField(unique=True)
    className = StringField(unique=True)
    originalName = StringField()
    originalClassName = StringField()
    owner = StringField()
    source = StringField()
    compiledSource = StringField()
    nRequests = IntField(default=0)
    isTool = BooleanField()
    # requests = ListField(StringField())
    accepted = BooleanField(default=False)

    meta = {
        'indexes': [[ ("accepted", 1), ("name", 1) ]]
    }

class Module(Document):
    name = StringField(unique=True)
    moduleType = StringField()
    category = StringField()
    description = StringField()
    repoName = StringField(unique=True)
    owner = StringField()
    url = StringField()
    githubURL = URLField()
    iconURL = StringField()
    thumbnailURL = StringField()
    source = StringField()
    compiledSource = StringField()
    local = BooleanField()
    lock = ReferenceField('Box', required=False)
    lastUpdate = DateTimeField(default=datetime.datetime.now)

    accepted = BooleanField(default=False)

    meta = {
        'indexes': [[ ("accepted", 1), ("name", 1) ]]
    }

class Site(Document):
    name = StringField(unique=True, required=True)
    box = ReferenceField(Box, required=True, reverse_delete_rule=CASCADE)

    # deprecated: put in data
    restrictedArea = BooleanField(default=False)
    disableToolbar = BooleanField(default=False)
    loadEntireArea = BooleanField(default=False)

    data = StringField(default='')

    meta = {
        'indexes': [[ ("name", 1) ]]
    }

# class Area(Document):
#     x = DecimalField()
#     y = DecimalField()
#     items = ListField(GenericReferenceField())
#     # paths = ListField(ReferenceField(Path))
#     # boxes = ListField(ReferenceField(Box))
#     # divs = ListField(ReferenceField(Div))
#     # areasToUpdate = ListField(ReferenceField(AreaToUpdate))

#     meta = {
#         'indexes': [[ ("x", 1), ("y", 1) ]]
#     }
