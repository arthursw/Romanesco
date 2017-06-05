# --- Romanesco --- #

Romanesco is a collaborative app.

# development

Requirements:

virtualenv RomanescoProject

pip install ...

 - Django==1.9.13
 - django-allauth
 - django-paypal
 - gevent-socketio
 - mongoengine

-------
gevent-socketio is a bit out-of-date:

Replace

from django.utils.importlib import import_module

by



or 

from importlib import import_module

in

lib/python2.7/site-packages/socketio/sdjango.py (line 6)

-------

Migrate

python manage.py migrate

-------

Creating an admin user

python manage.py createsuperuser

-------

Site does not exists:

from django.contrib.sites.models import Site
new_site = Site.objects.create(domain='localhost:8000', name='localhost:8000')
print new_site.id

http://stackoverflow.com/questions/11814059/site-matching-query-does-not-exist

-------

Client:

clone https://github.com/arthursw/romanesco-client-code.git beside Romanesco root directory



