#!/usr/bin/env python3

# zap - Completely remove unwanted macOS apps


from pathlib import Path
import argparse
import os
import plistlib
import subprocess


APP_IDENTIFIER_KEYS = [
    "CFBundleIdentifier",
    "CFBundleName",
    "CFBundleSignature"
]

DIRECTORIES_TO_SEARCH = [
    Path.home() / "Library",
    Path("/bin"),
    Path("/etc"),
    Path("/Library"),
    Path("/Users/Shared"),
    Path("/var")
]


def start_app():
    """Completely remove unwanted macOS apps."""

    app_path, verbose = get_args()

    print("Retrieving app identifiers...")
    identifiers = get_identifiers(app_path, verbose)
    if not identifiers:
        exit()

    print("Looking for related files and directories...")
    matches = search_directories(DIRECTORIES_TO_SEARCH, identifiers)
    matches.append(app_path)

    print("Moving related files and directories to the trash...")
    move_to_trash(matches, verbose)

    print()
    print("Operation complete.")
    print("Please review the deleted files before emptying trash.")


def get_args():
    """Configure argument parser including help text.

    Returns:
        Tuple of parsed arguments
    """

    parser = argparse.ArgumentParser(
        description="zap - completely remove unwanted macos apps",
        epilog="https://github.com/idianal/zap")

    parser.add_argument("app", help="absolute path of app to remove")
    parser.add_argument("--verbose", help="increase output verbosity",
                            action="store_true")

    args = parser.parse_args()
    return args.app, args.verbose


def get_identifiers(app_path, verbose=False):
    """Get identifiers for the app.
    
    Arguments:
        app_path - Path to the app
        verbose - Run in verbose mode

    Returns:
        Set of strings that identify the app
    """

    try:
        app_info_path = Path(app_path, "Contents/Info.plist").resolve(strict=True)
    except FileNotFoundError:
        print("Unable to read app info for " + app_path +
                ". Is it an absolute path to the app?")
        return

    # Get identifiers from app info
    app_info = plistlib.loads(app_info_path.read_bytes())
    identifiers = {app_info.get(key) for key in APP_IDENTIFIER_KEYS}

    # Remove invalid identifiers
    identifiers.discard(None)
    identifiers.discard("????")

    [print_verbose("- " + identifier, verbose=verbose) for identifier in identifiers]
    return identifiers


def search_directories(directories, identifiers):
    """Search directories recursively for the identifiers.

    Arguments:
        directories - Directories to look in
        identifiers - Identifiers to look for

    Returns:
        Paths to matching files and directories
    """

    matches = []

    for directory in directories:
        matches = matches + search_directory(directory, identifiers)

    return matches


def search_directory(directory, identifiers):
    """Search directory recursively for the identifiers.

    Arguments:
        directory - Directory to look in
        identifiers - Identifiers to look for

    Returns:
        Paths to matching files and directories
    """

    matches = []

    try:
        directory_items = list(directory.iterdir())
    except PermissionError:
        return matches

    for item in directory_items:
        try:
            if any(identifier in item.name for identifier in identifiers):
                matches.append(item)
            elif item.is_dir() and not item.is_symlink():
                matches = matches + search_directory(item, identifiers)
        except PermissionError:
            continue

    return matches


def move_to_trash(items, verbose=False):
    """Move files and directories to the trash.

    Arguments:
        items - Files and directories to move to the trash
        verbose - Run in verbose mode
    """

    # Implementation Note:
    # Use AppleScript to move file or directory to the trash.
    # https://apple.stackexchange.com/a/310084

    files = [("the POSIX file \"" + str(item) + "\"") for item in items]
    command = [
        "osascript",
        "-e",
        "tell app \"Finder\" to move {" + ", ".join(files) + "} to trash"
    ]

    [print_verbose("- " + str(item), verbose=verbose) for item in items]
    subprocess.call(command, stdout=open(os.devnull, 'w'),
                        stderr=open(os.devnull, 'w'))


def print_verbose(message="", verbose=False):
    """Print message if verbose argument is True

    Arguments:
        message - Message to print
        verbose - Indicates whether message should be printed
    """

    if verbose:
        print(message)


if __name__ == "__main__":
    start_app()
