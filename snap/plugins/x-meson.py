# -*- Mode:Python; indent-tabs-mode:nil; tab-width:4 -*-
#

import os
import snapcraft


class MesonPlugin(snapcraft.BasePlugin):

    @classmethod
    def schema(cls):
        schema = super().schema()
        schema['properties']['meson-parameters'] = {
            'type': 'array',
            'minitems': 1,
            'uniqueItems': True,
            'items': {
                'type': 'string',
            },
            'default': [],
        }

        return schema

    @classmethod
    def get_build_properties(cls):
        return ['meson-parameters']

    def __init__(self, name, options, project):
        super().__init__(name, options, project)
        self.snapbuildname = 'snapbuild'
        self.mesonbuilddir = os.path.join(self.builddir, self.snapbuildname)
        self.build_packages.append('meson')
        self.build_packages.append('ninja-build')

    def build(self):
        super().build()
        self._run_meson()
        self._run_ninja_build_default()
        self._run_ninja_install()

    def _run_meson(self):
        os.makedirs(self.mesonbuilddir, exist_ok=True)
        meson_command = ['meson']
        if self.options.meson_parameters:
            meson_command.extend(self.options.meson_parameters)
        meson_command.append(self.snapbuildname)
        env = os.environ.copy()
        env['PKG_CONFIG_PATH'] = self.project.stage_dir + '/usr/lib/pkgconfig:/usr/lib/' + self.project.arch_triplet + '/pkgconfig:/usr/lib/pkgconfig'
        env['VAPIDIR'] = self.project.stage_dir + '/usr/share/vala/vapi'
        env['GI_TYPELIB_PATH'] = self.project.stage_dir +  '/usr/lib/' + self.project.arch_triplet + '/girepository-1.0:/usr/lib/' + self.project.arch_triplet + '/girepository-1.0'
        env['XDG_DATA_DIRS'] = self.project.stage_dir + '/usr/share:/usr/share'
        self.run(meson_command, env=env)

    def _run_ninja_build_default(self):
        ninja_command = ['ninja']
        env = os.environ.copy()
        env['PKG_CONFIG_PATH'] = self.project.stage_dir + '/usr/lib/pkgconfig:/usr/lib/' + self.project.arch_triplet + '/pkgconfig:/usr/lib/pkgconfig'
        env['VAPIDIR'] = self.project.stage_dir + '/usr/share/vala/vapi'
        env['GI_TYPELIB_PATH'] = self.project.stage_dir +  '/usr/lib/' + self.project.arch_triplet + '/girepository-1.0:/usr/lib/' + self.project.arch_triplet + '/girepository-1.0'
        env['XDG_DATA_DIRS'] = self.project.stage_dir + '/usr/share:/usr/share'
        self.run(ninja_command, env=env, cwd=self.mesonbuilddir)

    def _run_ninja_install(self):
        env = os.environ.copy()
        env['DESTDIR'] = self.installdir
        ninja_install_command = ['ninja', 'install']
        self.run(ninja_install_command, env=env, cwd=self.mesonbuilddir)
