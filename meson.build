project(
	'moss',
	['d'],
	version: '0.0.0',
	license: [
		'ZLib',
	]
)

pkgconf = import('pkgconfig')

# Configure moss-vendor
subproject('moss-vendor',
	default_options: [
		'with_elf=true',
		'with_rocksdb=true',
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
	'source/moss/cli/index_command.d',
	'source/moss/cli/list.d',
	'source/moss/cli/version_command.d',
	'source/moss/cli/install_command.d',
	'source/moss/cli/remove_command.d',
	'source/moss/cli/extract_command.d',
	'source/moss/cli/inspect_command.d',
	'source/moss/cli/info_command.d',
	'source/moss/cli/list_available.d',
	'source/moss/cli/list_installed.d',
	'source/moss/cli/list_packages.d',
	'source/moss/cli/package.d',
	'source/moss/cli/update_command.d',
	'source/moss/storage/db/cachedb.d',
	'source/moss/storage/db/package.d',
	'source/moss/storage/db/packagesdb.d',
	'source/moss/storage/db/statedb/package.d',
	'source/moss/storage/db/statedb/selection.d',
	'source/moss/storage/db/statedb/state.d',
	'source/moss/storage/db/layoutdb.d',
	'source/moss/storage/db/metadb.d',
	'source/moss/storage/diskpool.d',
	'source/moss/storage/package.d',
	'source/moss/storage/cachepool.d',
	'source/moss/controller/plugins/cobble.d',
	'source/moss/controller/plugins/package.d',
	'source/moss/controller/plugins/activepackages.d',
	'source/moss/controller/plugins/repo.d',
	'source/moss/controller/rootconstructor.d',
	'source/moss/controller/archivecacher.d',
	'source/moss/controller/remote.d',
	'source/moss/controller/package.d',
	'source/moss/context.d',
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
