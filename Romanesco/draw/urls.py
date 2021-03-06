from django.conf.urls import patterns, include, url
from draw import views
import socketio.sdjango

socketio.sdjango.autodiscover()

urlpatterns = patterns('',
    # hack for Brackets Theseus...
    url(r'^draw/templates/index\.html', views.index, name='index'),
    url(r'^draw/index\.html', views.index, name='index'),
    url(r'^index\.html', views.index, name='index'),

    url(r'^$', views.index, name='index'),
    url(r'^ajaxCall/$', views.ajaxCall),

    # url(r'^#(-?\d+(?:\.\d+)?),(-?\d+(?:\.\d+)?)$', views.index, name='index'),
    # url(r'^(?P<owner>[\w-]+)/(?P<name>[\w-]+)/#(-?\d+(?:\.\d+)?),(-?\d+(?:\.\d+)?)$', views.index, name='index'),
    url(r'^#(?P<x>[\d.]+),(?P<y>[\d.]+)$', views.index, name='index'),
    url(r'^#(?P<owner>[\w]+)/(?P<city>[\w-]+)$', views.index, name='index'),
    url(r'^#(?P<owner>[\w]+)/(?P<city>[\w-]+)/(?P<x>[\d.]+),(?P<y>[\d.]+)$', views.index, name='index'),
    url(r'^#sites/(?P<site>[\w]+)$', views.index, name='index'),
    url(r'^#sites/(?P<site>[\w]+)/(?P<x>[\d.]+),(?P<y>[\d.]+)$', views.index, name='index'),
    url(r'^#(?P<owner>[\w]+)/(?P<city>[\w-]+)/sites/(?P<site>[\w]+)$', views.index, name='index'),
    url(r'^#(?P<owner>[\w]+)/(?P<city>[\w-]+)/sites/(?P<site>[\w]+)/(?P<x>[\d.]+),(?P<y>[\d.]+)$', views.index, name='index'),
    url(r'^rasterizer/$', views.index),
    url(r'^rasterizer/#(?P<x>[\d.]+),(?P<y>[\d.]+)$', views.index),
    # url(r'^rasterizer/#(-?\d+(?:\.\d+)?),(-?\d+(?:\.\d+)?)$', views.rasterizer, name='index'),
    # url(r'^([\w,.,-]+)$', views.index, name='index'),
        # url(r'^(?P<sitename>([\w,.,-]+)).romanesc.co/', views.index, name='index'),
    url("^socket\.io", include(socketio.sdjango.urls)),
    url(r'^romanescoin/paypal/', include('paypal.standard.ipn.urls')),
        url(r'^paypal/romanescoin/return/$', views.romanescoinsReturn),
        url(r'^paypal/romanescoin/cancel/$', views.romanescoinsCancel),
)