#!/usr/bin/env python3
# convert_symlinks.py - Konvertiert absolute Symlinks zu relativen

import os
import sys
from pathlib import Path

def convert_symlinks(directory):
    """Konvertiert alle absoluten Symlinks im Verzeichnis zu relativen"""
    
    directory = Path(directory).resolve()
    converted = 0
    skipped = 0
    errors = 0
    
    print(f"Konvertiere Symlinks in: {directory}")
    
    for item in directory.iterdir():
        if not item.is_symlink():
            continue
            
        target = os.readlink(item)
        
        # Prüfe ob absoluter Pfad
        if not target.startswith('/'):
            print(f"Überspringe (relativ): {item.name} -> {target}")
            skipped += 1
            continue
            
        print(f"Bearbeite: {item.name} -> {target}")
        
        # Berechne relativen Pfad
        try:
            target_path = Path(target)
            if not target_path.exists():
                print(f"  WARNUNG: Ziel existiert nicht: {target}")
                errors += 1
                continue
                
            # Berechne relativen Pfad vom Symlink-Verzeichnis zum Ziel
            relative = os.path.relpath(target, start=item.parent)
            
            # Backup erstellen (optional)
            # backup = item.with_suffix('.bak')
            # if not backup.exists():
            #     os.symlink(os.readlink(item), backup)
            
            # Neuen relativen Link erstellen
            os.unlink(item)
            os.symlink(relative, item)
            
            print(f"  ✓ Konvertiert: {item.name} -> {relative}")
            converted += 1
            
        except Exception as e:
            print(f"  ✗ Fehler: {e}")
            errors += 1
    
    print(f"\nZusammenfassung: Konvertiert={converted}, Übersprungen={skipped}, Fehler={errors}")
    return converted, skipped, errors

if __name__ == "__main__":
    directory = sys.argv[1] if len(sys.argv) > 1 else "."
    convert_symlinks(directory)

