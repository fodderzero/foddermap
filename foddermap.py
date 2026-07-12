"""
FodderMap - External Attack Surface Mapping Tool
Phase 1.1: Core Setup + Basic CLI
"""

import argparse
import sys
from datetime import datetime
from pathlib import Path

def create_output_directory(target: str) -> Path:
    """Create a timestamped output directory for this run."""
    timestamp = datetime.now().strftime("%Y-%m-%d_%H%M")
    output_dir = Path("output") / f"{target}_{timestamp}"
    output_dir.mkdir(parents=True, exist_ok=True)
    return output_dir

def validate_target(target: str) -> bool:
    """Very basic domain validation. We'll improve this later."""
    if "." not in target:
        return False
    if len(target) < 4:
        return False
    return True

def main():
    parser = argparse.ArgumentParser(
        description="FodderMap - External Attack Surface Mapping Tool",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
    python foddermap.py -t example.com
    python foddermap.py --target example.com
"""
    )

    parser.add_argument(
        "-t", "--target",
        help="Target domain to map (e.g. example.com)"
    )

    parser.add_argument(
        "-v", "--version",
        action="version",
        version="FodderMap v0.1.0 (Phase 1.1)"
    )
    args = parser.parse_args()

    if args.target is None:
        parser.print_help()
        print("\n[!] Error: --target is required")
        sys.exti(1)

    target = args.target.strip().lower()

    if not validate_target(target):
        print(f"[!] Invalid target: {target}")
        print("[!] Target should be a valid domain (e.g. example.com)")
        sys.exit(1)

    print(f"[+] Starting FodderMap against: {target}")
    print(f"[+] Phase 1.1 - Core Setup")

    output_dir = create_output_directory(target)
    print(f"[+] Output directory created: {output_dir}")

    print(f"[+] FodderMap intialization complete.")
    print(f"[+] Ready for Phase 1.2 (Passive Recon)")


if __name__ == "__main__":
    main()