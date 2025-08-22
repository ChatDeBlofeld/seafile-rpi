# Requirements

Messy topic and currently not handled properly. The idea is to install all pure Python dependencies at build time and bundle them with the package. Dependencies that ship binaries bound to a specific Python version are ignored and have to be installed on the target system. Furthermore, if a dependency is pure Python but has C (or whatever) dependencies, these transitive dependencies are ignored as well (all Python packages are installed with `--no-deps`).

Maintaining this list is done by hand. The files are:

- `upstream.txt`: Dependencies for [Seahub](https://github.com/haiwen/seahub/blob/master/requirements.txt)
and [Seafdav](https://github.com/haiwen/seafdav/blob/master/requirements.txt) merged and tinkered.
- `ignored.txt`: Ignored dependencies because they all ship binaries bound to a specific python version. Will have to be installed on the runtime environment.
- `requirements.txt`: Result of `pip freeze` after installation of all upstream dependencies, less the ignored ones. Can be updated using `update.sh`.
