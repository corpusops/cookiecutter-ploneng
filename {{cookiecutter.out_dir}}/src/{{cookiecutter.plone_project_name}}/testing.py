# -*- coding: utf-8 -*-
from plone.app.contenttypes.testing import PLONE_APP_CONTENTTYPES_FIXTURE
from plone.app.robotframework.testing import REMOTE_LIBRARY_BUNDLE_FIXTURE
from plone.app.testing import applyProfile
from plone.app.testing import FunctionalTesting
from plone.app.testing import IntegrationTesting
from plone.app.testing import PloneSandboxLayer
from plone.testing.zope import WSGI_SERVER_FIXTURE

import {{cookiecutter.plone_project_name}}


class {{cookiecutter.plone_project_name.capitalize()}}Layer(PloneSandboxLayer):

    defaultBases = (PLONE_APP_CONTENTTYPES_FIXTURE,)

    def setUpZope(self, app, configurationContext):
        # Load any other ZCML that is required for your tests.
        # The z3c.autoinclude feature is disabled in the Plone fixture base
        # layer.
        import plone.restapi
        self.loadZCML(package=plone.restapi)
        self.loadZCML(package={{cookiecutter.plone_project_name}})

    def setUpPloneSite(self, portal):
        applyProfile(portal, '{{cookiecutter.plone_project_name}}:default')


{{cookiecutter.plone_project_name.upper()}}_FIXTURE = {{cookiecutter.plone_project_name.capitalize()}}Layer()


{{cookiecutter.plone_project_name.upper()}}_INTEGRATION_TESTING = IntegrationTesting(
    bases=({{cookiecutter.plone_project_name.upper()}}_FIXTURE,),
    name='{{cookiecutter.plone_project_name.capitalize()}}Layer:IntegrationTesting',
)


{{cookiecutter.plone_project_name.upper()}}_FUNCTIONAL_TESTING = FunctionalTesting(
    bases=({{cookiecutter.plone_project_name.upper()}}_FIXTURE,),
    name='{{cookiecutter.plone_project_name.capitalize()}}Layer:FunctionalTesting',
)


{{cookiecutter.plone_project_name.upper()}}_ACCEPTANCE_TESTING = FunctionalTesting(
    bases=(
        {{cookiecutter.plone_project_name.upper()}}_FIXTURE,
        REMOTE_LIBRARY_BUNDLE_FIXTURE,
        WSGI_SERVER_FIXTURE,
    ),
    name='{{cookiecutter.plone_project_name.capitalize()}}Layer:AcceptanceTesting',
)
