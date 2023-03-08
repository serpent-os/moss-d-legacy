project(
	'moss',
	['d'],
	version: '0.0.0',
	license: [
		'Zlib',
	]
)

compiler = meson.get_compiler('d')
if compiler.get_id() == 'llvm' and compiler.version().version_compare('<1.31.0')
	error('LDC must be at least 1.31.0')
endif

# libmoss without recipe (stone.yml) support
libmoss = subproject('libmoss',
	default_options: [
		'default_library=static',
		'with-format=binary'
	],
	version: '>=1.1.0'
)

# Grab moss-config
link_libmoss_config = libmoss.get_variable('link_libmoss_config')

# Grab moss-core
link_libmoss_core = libmoss.get_variable('link_libmoss_core')

# Grab moss-db
link_libmoss_db = libmoss.get_variable('link_libmoss_db')

# Grab moss-deps
link_libmoss_deps = libmoss.get_variable('link_libmoss_deps')

# Grab moss-fetcher
link_libmoss_fetcher = libmoss.get_variable('link_libmoss_fetcher')

# Grab moss-format
link_libmoss_format = libmoss.get_variable('link_libmoss_format_binary')

moss_sources = [
	'source/moss/client/activeplugin.d',
	'source/moss/client/cobbleplugin.d',
	'source/moss/client/cli/index.d',
	'source/moss/client/cli/info.d',
	'source/moss/client/cli/inspect.d',
	'source/moss/client/cli/install.d',
	'source/moss/client/cli/list_available.d',
	'source/moss/client/cli/list_installed.d',
	'source/moss/client/cli/list.d',
	'source/moss/client/cli/package.d',
	'source/moss/client/cli/remote_add.d',
	'source/moss/client/cli/remote_list.d',
	'source/moss/client/cli/remote_update.d',
	'source/moss/client/cli/remote_remove.d',
	'source/moss/client/cli/remote.d',
	'source/moss/client/cli/remove.d',
	'source/moss/client/cli/search.d',
	'source/moss/client/impl.d',
	'source/moss/client/installation.d',
	'source/moss/client/installdb.d',
	'source/moss/client/label.d',
	'source/moss/client/layoutdb.d',
	'source/moss/client/metadb.d',
	'source/moss/client/package.d',
	'source/moss/client/progressbar.d',
	'source/moss/client/remoteplugin.d',
	'source/moss/client/remotes.d',
	'source/moss/client/renderer.d',
	'source/moss/client/statedb.d',
	'source/moss/client/systemcache.d',
	'source/moss/client/systemroot.d',
	'source/moss/client/ui.d',
	'source/main.d',
]

moss_includes = [
    include_directories('source'),
]

moss_deps = [
    link_libmoss_config,
    link_libmoss_core,
    link_libmoss_db,
    link_libmoss_deps,
    link_libmoss_format,
    link_libmoss_fetcher,
]

moss = executable(
	'moss',
	moss_sources,
	install: true,
	dependencies: moss_deps,
	include_directories: moss_includes,
	d_import_dirs: include_directories('data'),
	link_args: ['--link-defaultlib-shared=false'],
)
