# --- Romanesco --- #

Romanesco is a collaborative app.

# development

Requirements:

virtualenv RomanescoProject

pip install ...

Django
django-allauth
django-paypal
gevent-socketio
mongoengine

Replaced

from django.utils.importlib import import_module

by

from importlib import import_module

in

lib/python2.7/site-packages/socketio/sdjango.py (line 6)
