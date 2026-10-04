#!/usr/bin/env python3
"""Prepare a local candidate or sign, notarize, and package a Mac release."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import sys

ROOT = Path(__file__).resolve().parent
APP = ROOT / 'build/release/AppleMailWidgets.app'
EXT = APP / 'Contents/PlugIns/AppleMailWidgetsWidget.appex'


def run(*args, capture=False, **kwargs):
    result = subprocess.run([str(a) for a in args], check=True, text=True,
                            stdout=subprocess.PIPE if capture else None, **kwargs)
    return result.stdout if capture else None


def validate_version(value):
    if not re.fullmatch(r'\d{1,4}\.\d{1,2}\.\d{1,2}', value):
        raise argparse.ArgumentTypeError('Use a numeric version such as 0.1.0.')
    return value


def validate_build(value):
    if not re.fullmatch(r'[1-9]\d{0,3}', value):
        raise argparse.ArgumentTypeError('Use a build number from 1 to 9999.')
    return value


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('mode', choices=['prepare', 'notarize'])
    parser.add_argument('version', type=validate_version)
    parser.add_argument('build', type=validate_build)
    args = parser.parse_args()
    identity = os.environ.get('SIGNING_IDENTITY', '')
    profile = os.environ.get('NOTARY_PROFILE', 'AppleMailWidgets')
    output = ROOT / f'dist/AppleMailWidgets-{args.version}-build{args.build}-arm64.zip'
    if args.mode == 'notarize':
        if not identity.startswith('Developer ID Application: '):
            parser.error('Set SIGNING_IDENTITY to your Developer ID Application certificate name.')
        identities = run('/usr/bin/security', 'find-identity', '-v', '-p', 'codesigning', capture=True)
        if f'"{identity}"' not in identities:
            parser.error('That Developer ID Application certificate and private key are not available in Keychain.')
        if output.exists() or output.with_suffix('.zip.sha256').exists():
            parser.error('This release file already exists. Use a new build number.')
        # Check saved authentication before doing a build or uploading anything.
        run('/usr/bin/xcrun', 'notarytool', 'history', '--keychain-profile', profile,
            '--output-format', 'json', capture=True)
    env = {**os.environ, 'BUILD_VARIANT': 'release', 'APP_VERSION': args.version,
           'APP_BUILD_NUMBER': args.build}
    run(ROOT / 'build-local.sh', cwd=ROOT, env=env)
    if args.mode == 'prepare':
        print(f'Prepared local candidate: {APP}\nNot Developer ID signed or notarized. Do not publish this candidate.')
        return
    # Sign nested code first. Both executables need Hardened Runtime and a timestamp.
    for bundle, entitlements in [(EXT, 'Widget.entitlements'), (APP, 'App.entitlements')]:
        run('/usr/bin/codesign', '--force', '--sign', identity, '--options', 'runtime',
            '--timestamp', '--entitlements', ROOT / 'Config' / entitlements, bundle)
    run('/usr/bin/codesign', '--verify', '--deep', '--strict', APP)
    submission = ROOT / 'build/release/notary-upload.zip'
    if submission.exists():
        submission.unlink()
    run('/usr/bin/ditto', '-c', '-k', '--keepParent', APP, submission)
    record = ROOT / 'build/release/notary-submission.json'
    # Save the submission ID immediately, including when the subsequent wait times out.
    response = run('/usr/bin/xcrun', 'notarytool', 'submit', submission,
                   '--keychain-profile', profile, '--output-format', 'json', capture=True)
    record.write_text(response)
    request_id = json.loads(response)['id']
    print(f'Notarization submitted: {request_id}', flush=True)
    wait = subprocess.run(['/usr/bin/xcrun', 'notarytool', 'wait', request_id,
                           '--keychain-profile', profile, '--timeout', '10m',
                           '--output-format', 'json'], text=True, capture_output=True)
    (ROOT / 'build/release/notary-status.json').write_text(wait.stdout)
    try:
        accepted = json.loads(wait.stdout).get('status') == 'Accepted'
    except json.JSONDecodeError:
        accepted = False
    if not accepted:
        print(wait.stderr, file=sys.stderr)
        print(f'No release ZIP created. Submission ID is saved in {record}.\n'
              'Inspect its status and log with notarytool before retrying.', file=sys.stderr)
        sys.exit(1)
    run('/usr/bin/xcrun', 'stapler', 'staple', APP)
    run('/usr/bin/xcrun', 'stapler', 'validate', APP)
    run('/usr/bin/codesign', '--verify', '--deep', '--strict', APP)
    run('/usr/sbin/spctl', '--assess', '--type', 'execute', '--verbose=2', APP)
    output.parent.mkdir(exist_ok=True)
    # Repackage AFTER stapling. The upload archive does not contain the ticket.
    run('/usr/bin/ditto', '-c', '-k', '--keepParent', APP, output)
    checksum = hashlib.sha256(output.read_bytes()).hexdigest()
    output.with_suffix('.zip.sha256').write_text(f'{checksum}  {output.name}\n')
    print(f'Notarized release: {output}')


if __name__ == '__main__':
    try:
        main()
    except subprocess.CalledProcessError as error:
        print(f'Release stopped: {Path(error.cmd[0]).name} exited {error.returncode}.', file=sys.stderr)
        sys.exit(1)
