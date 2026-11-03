"""Credentials of technical accounts (scanner, transcription worker) — constat R3.

Order of sources, the first one present wins:
1. environment variables  <PREFIX>_EMAIL and <PREFIX>_PASSWORD (secret manager, systemd, container);
2. a file named by <PREFIX>_FILE (mounted secret);
3. the historical local file under .local-auth/.

A credentials file must be a regular file, not a symlink, readable by its owner only
(no group or other permission bit). Values are never logged.
"""
import json
import os
import pathlib
import stat


class CredentialsUnavailable(Exception):
    pass


def _from_file(path):
    path = pathlib.Path(path)
    try:
        info = os.lstat(path)
    except OSError:
        raise CredentialsUnavailable('Fichier de secret absent') from None
    if stat.S_ISLNK(info.st_mode) or not stat.S_ISREG(info.st_mode):
        raise CredentialsUnavailable('Fichier de secret invalide')
    if info.st_mode & 0o077:
        raise CredentialsUnavailable('Fichier de secret lisible par d’autres utilisateurs (0600 requis)')
    try:
        data = json.loads(path.read_text())
    except (OSError, ValueError):
        raise CredentialsUnavailable('Fichier de secret illisible') from None
    return data


def load(prefix, default_file):
    """Return {'email': ..., 'password': ...} for the technical account `prefix`."""
    email = os.environ.get(prefix + '_EMAIL')
    password = os.environ.get(prefix + '_PASSWORD')
    if email or password:
        data = {'email': email, 'password': password}
    elif os.environ.get(prefix + '_FILE'):
        data = _from_file(os.environ[prefix + '_FILE'])
    else:
        data = _from_file(default_file)
    if not isinstance(data, dict) or not isinstance(data.get('email'), str) or not isinstance(data.get('password'), str) or not data['email'] or not data['password']:
        raise CredentialsUnavailable('Identifiants incomplets')
    return {'email': data['email'], 'password': data['password']}
