# -*- coding: utf-8 -*-
from south.utils import datetime_utils as datetime
from south.db import db
from south.v2 import SchemaMigration
from django.db import models


class Migration(SchemaMigration):

    def forwards(self, orm):
        # Deleting model 'UserProfile'
        db.delete_table('user_profile')


    def backwards(self, orm):
        # Adding model 'UserProfile'
        db.create_table('user_profile', (
            ('admin', self.gf('django.db.models.fields.BooleanField')(default=False)),
            ('user', self.gf('django.db.models.fields.related.OneToOneField')(related_name='profile', unique=True, to=orm['auth.User'])),
            (u'id', self.gf('django.db.models.fields.AutoField')(primary_key=True)),
            ('romanescoins', self.gf('django.db.models.fields.IntegerField')(default=0)),
        ))
        db.send_create_signal(u'draw', ['UserProfile'])


    models = {
        
    }

    complete_apps = ['draw']