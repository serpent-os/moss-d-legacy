project(
	'moss',
	['d'],
	version: '0.0.0',
	license: [
		'Zlib',
	]
)

pkgconf = import('pkgconfig')

# Configure moss-vendor
subproject('moss-vendor',
	default_options: [
		'with_elf=true',
		'with_lmdb=true',
		'with_xxhash=true',
		'with_yaml=true',
		'with_zstd=true',
	]
)

# Grab moss-config
moss_config = subproject('moss-config')
link_libmoss_config = moss_config.get_variable('link_libmoss_config')

# Grab moss-core
moss_core = subproject('moss-core')
link_libmoss_core = moss_core.get_variable('link_libmoss_core')

# Grab moss-db
moss_db = subproject('moss-db')
link_libmoss_db = moss_db.get_variable('link_libmoss_db')

# Grab moss-deps
moss_deps = subproject('moss-deps')
link_libmoss_deps = moss_deps.get_variable('link_libmoss_deps')

# Grab moss-fetcher
moss_fetcher = subproject('moss-fetcher')
link_libmoss_fetcher = moss_fetcher.get_variable('link_libmoss_fetcher')

# Grab moss-format
moss_format = subproject('moss-format')
link_libmoss_format = moss_format.get_variable('link_libmoss_format_binary')

moss_sources = [
	'source/moss/client/impl.d',
	'source/moss/client/sizing.d',
	'source/moss/client/ui.d',
	'source/moss/client/activeplugin.d',
	'source/moss/client/remotes.d',
	'source/moss/client/statedb.d',
	'source/moss/client/package.d',
	'source/moss/client/remoteplugin.d',
	'source/moss/client/systemroot.d',
	'source/moss/client/cli/remote_add.d',
	'source/moss/client/cli/package.d',
	'source/moss/client/cli/list.d',
	'source/moss/client/cli/search.d',
	'source/moss/client/cli/info.d',
	'source/moss/client/cli/list_available.d',
	'source/moss/client/cli/remote_update.d',
	'source/moss/client/cli/install.d',
	'source/moss/client/cli/remove.d',
	'source/moss/client/cli/remote_list.d',
	'source/moss/client/cli/remote.d',
	'source/moss/client/cli/list_installed.d',
	'source/moss/client/systemcache.d',
	'source/moss/client/installdb.d',
	'source/moss/client/installation.d',
	'source/moss/client/progressbar.d',
	'source/moss/client/renderer.d',
	'source/moss/client/layoutdb.d',
	'source/moss/client/metadb.d',
	'source/moss/client/label.d',
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
	link_args: ['--link-defaultlib-shared=false'],
)
