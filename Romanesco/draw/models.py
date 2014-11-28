from django.contrib.auth.models import User
from django.db import models
import urllib
from allauth.account.models import EmailAddress
from allauth.socialaccount.models import SocialAccount
import hashlib
from mongoengine import *
import datetime
from allauth.account.signals import user_logged_in
from django.dispatch import receiver

# --- django-allauth : sqlite --- #

# import pdb; pdb.set_trace()
# object.__dict___

# to update the database after modifying model, use south: 
# http://south.readthedocs.org/en/latest/tutorial/part1.html
# python manage.py schemamigration draw --auto
# python manage.py migrate draw

class UserProfile(models.Model):
    user = models.OneToOneField(User, related_name='profile')
    romanescoins = models.IntegerField(default=0)
 
    def __unicode__(self):
        return "{}'s profile".format(self.user.username)
 
    class Meta:
        db_table = 'user_profile'
 
    def account_verified(self):
        if self.user.is_authenticated:
            result = EmailAddress.objects.filter(email=self.user.email)
            if len(result):
                return result[0].verified
        return False

    def profile_image_url(self):

        fb_uid = SocialAccount.objects.filter(user_id=self.user.id, provider='facebook')

        if len(fb_uid):
            return "http://graph.facebook.com/{}/picture?width=64&height=64".format(fb_uid[0].uid)

        socialAccount = self.user.socialaccount_set.filter(provider='google')

        if len(socialAccount)>0:
            return socialAccount[0].extra_data['picture']

        # google_uid = SocialAccount.objects.filter(user_id=self.user.id, provider='google')
        # if len(google_uid):
        #     return "https://plus.google.com/s2/photos/profile/{}?sz=64".format(google_uid[0].uid)

        defaultUrl = urllib.quote_plus("http://www.mediafire.com/convkey/7e65/v9zp48cdnsccr4d6g.jpg")

        return "http://www.gravatar.com/avatar/{}?s=64&d={}".format(hashlib.md5(self.user.email).hexdigest(), defaultUrl)

    # @receiver(user_logged_in)
    # def user_logged_in_(request, user, sociallogin, **kwargs):
        # import pdb; pdb.set_trace()
        # google image accessible via  sociallogin.account.extra_data['picture']
        # return

User.profile = property(lambda u: UserProfile.objects.get_or_create(user=u)[0])

# --- MongoDB --- #

class Path(Document):
    planetX = DecimalField()
    planetY = DecimalField()
    points = LineStringField()
    owner = StringField()
    date = DateTimeField(default=datetime.datetime.now)
    object_type = StringField(default='brush')
    locked = BooleanField(default=False)

    data = StringField(default='')

    meta = {
        'indexes': [[ ("planetX", 1), ("planetY", 1), ("points", "2dsphere"), ("date", 1) ]]
    }

class Box(Document):
    planetX = DecimalField()
    planetY = DecimalField()
    box = PolygonField()
    owner = StringField()
    date = DateTimeField(default=datetime.datetime.now)
    object_type = StringField()
    url = URLField(verify_exists=True, required=False)
    name = StringField()
    message = StringField()

    data = StringField(default='')
    
    meta = {
        'indexes': [[ ("planetX", 1), ("planetY", 1), ("box", "2dsphere"), ("date", 1) ]]
    }

class Div(Document):
    planetX = DecimalField()
    planetY = DecimalField()
    box = PolygonField()
    owner = StringField()
    date = DateTimeField(default=datetime.datetime.now)
    object_type = StringField()
    url = StringField(required=False)
    message = StringField()
    locked = BooleanField(default=False)

    data = StringField(default='')

    meta = {
        'indexes': [[ ("planetX", 1), ("planetY", 1), ("box", "2dsphere"), ("date", 1) ]]
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

class Site(Document):
    name = StringField(unique=True, required=True)
    box = ReferenceField(Box, required=True, reverse_delete_rule=CASCADE)
    restrictedArea = BooleanField(default=False)
    disableToolbar = BooleanField(default=False)
    loadEntireArea = BooleanField(default=False)
    
    meta = {
        'indexes': [[ ("name", 1) ]]
    }
