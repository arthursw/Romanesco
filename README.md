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


## Fix gevent-socketio

gevent-socketio is a bit out-of-date:

Replace

from django.utils.importlib import import_module

by



or 

from importlib import import_module

in

lib/python2.7/site-packages/socketio/sdjango.py (line 6)


## Migrate

`python manage.py migrate`


## Creating an admin user

`python manage.py createsuperuser`

## Create site

If the site does not exists, you will have the following error: `Site matching query does not exist`

in python shell:

`python manage.py shell`


`from django.contrib.sites.models import Site`

`new_site = Site.objects.create(domain='localhost:8000', name='localhost:8000')`
`print new_site.id`

Now set that site ID in your settings.py to SITE_ID

http://stackoverflow.com/questions/11814059/site-matching-query-does-not-exist

-------

Client:

clone https://github.com/arthursw/romanesco-client-code.git beside Romanesco root directory



