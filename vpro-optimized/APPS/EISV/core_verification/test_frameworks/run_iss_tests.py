import argparse, pathlib, filecmp, glob
from os import environ, devnull, remove
from subprocess import call, Popen
from time import sleep
from distutils.dir_util import copy_tree
from shutil import rmtree
from time import time
from sys import exit

#
# Example call for a single test with output to console:
#
# python3 run_iss_tests.py 
#    --sim-lib-dir='/home/gesper/repositories/vpro_sys_optimized/TOOLS/VPRO/ISS/iss_lib' 
#    --aux-lib-dir='/home/gesper/repositories/vpro_sys_optimized/TOOLS/VPRO/ISS/common_lib' 
#    -t ADD.cpp -v
#

# ------------------------
# === Begin Pre Config ===
# ------------------------

PRE_CONFIG_TARGET_REL = 'eisv-target/iss'
PRE_CONFIG_SRC_FOLDER_REL = 'eisv-vpro-tests/src'
PRE_CONFIG_REF_FOLDER_REL = 'eisv-vpro-tests/references'
PRE_CONFIG_PATH_REL = 'eisv-vpro-tests/Makefrag.iss'

# ------------------------
# ===  END  Pre Config ===
# ------------------------

ROOT = pathlib.Path(__file__).parent.resolve()

REQ_VPRO_SIM_LIB_DIR = False if 'vpro_sim_lib_dir' in environ else True
#if(REQ_VPRO_SIM_LIB_DIR):
#    print("ENV <vpro_sim_lib_dir> not set!")
REQ_VPRO_AUX_LIB_DIR = False if 'vpro_aux_lib_dir' in environ else True
#if(REQ_VPRO_AUX_LIB_DIR):
#    print("ENV <vpro_aux_lib_dir> not set!")

MSG_ENV = """====
Execute this in the iss root:

export vpro_sim_lib_dir=./iss_lib
export vpro_aux_lib_dir=./common_lib
----
Execute single tests with (e.g. ADD ADDI)
python3 run_iss_test.py -t ADD.cpp ADDI.cpp -v
====
"""



if __name__ == '__main__':
    parser = argparse.ArgumentParser(description='runs the core_verification with the specified tests on the iss target')

    parser.add_argument('--sim-lib-dir', help='path to VPRO_SIM_LIB (default: environment vpro_sim_lib_dir)', required=REQ_VPRO_SIM_LIB_DIR, default=environ.get('vpro_sim_lib_dir'))
    parser.add_argument('--aux-lib-dir', help='path to VPRO_AUX_LIB (default: environment vpro_aux_lib_dir)', required=REQ_VPRO_AUX_LIB_DIR, default=environ.get('vpro_aux_lib_dir'))
    parser.add_argument('-o', '--out', help='path to save signature dumps', default=str(ROOT / PRE_CONFIG_TARGET_REL / 'dumps'))
    parser.add_argument('-i', '--in', help='path of reference signature_dumps', default=str(ROOT / PRE_CONFIG_REF_FOLDER_REL), dest='reference_folder')

    group = parser.add_mutually_exclusive_group()

    #group.add_argument('-a', '--all', action='store_true', help='runs all tests')      # option that takes a value
    group.add_argument('-t', '--test', nargs='*', help='runs test specified by main cpp like "MULL_POS.cpp ADD.cpp"')
    group.add_argument('-c', '--config-file', help='path to runs pre-configured selection of tests', default=str(ROOT/PRE_CONFIG_PATH_REL))
        
    
    parser.add_argument('--src-folder', metavar='SRC', default=str(ROOT / PRE_CONFIG_SRC_FOLDER_REL), help='path to src directory')
    parser.add_argument('--target', default=str(ROOT / PRE_CONFIG_TARGET_REL), help='path to build target directory')
    parser.add_argument('-v', '--verbose', action='store_true') 
    parser.add_argument('-j', action="store_true", help='Runs the tests simultaneously')


    args = parser.parse_args()
    print(args)


    print("Python Script: RUN ISS TESTS")


    ## Check OUT Folder
    outpath = pathlib.Path(args.out)
    outpath.mkdir(parents=True, exist_ok=True)

    
    build_prefix = "build_i"
    build_folder_path = str(ROOT / PRE_CONFIG_TARGET_REL / "build_release")

    
    # remove old build folder
    """
    files = glob.glob(str(ROOT / PRE_CONFIG_TARGET_REL / build_prefix) + "*")
    for file in files:
        rmtree(file)
    """
    
    # remove old signature dumps

    files = glob.glob(str(outpath / "*"))
    for file in files:
        remove(file)

    config_test = []
    if args.test == None:
        config = None
        with open(args.config_file, 'r') as cf:
            config = cf.read()

        config_comments = ""
        test_attribute_line_begin = 0
        test_attribute_line_end = 0
        test_attribute_found = False

        current_line = 0
        for line in config.split('\n'):
            if line.strip() == '':
                continue
            elif line.strip()[0] == '#':
                continue

            if "rv32_vpro_sc_tests" in line:
                test_attribute_line_begin = current_line
                test_attribute_found = True

            if '#' in line.strip():
                modline = line.strip().split('#')[0]
                config_comments += modline.strip() + '\n'
                current_line += 1

                if test_attribute_found and modline.strip()[-1] != '\\':
                    test_attribute_line_end = current_line
                    break
            else:
                config_comments += line.strip() + '\n'
                current_line += 1

                if test_attribute_found and line.strip()[-1] != '\\':
                    test_attribute_line_end = current_line
                    break

            
            

        config_test_trim = config_comments.replace('\\','').split('\n')[test_attribute_line_begin:test_attribute_line_end]

        firsttest = config_test_trim[0].split('=')[1].strip()
        if firsttest != '':
            config_test.append(firsttest)

        for test_trim in config_test_trim[1:]:
            config_test.append(test_trim.strip() + ".cpp")
    else:
        config_test = args.test


    # generate libs
    tmp_lib_build_path = pathlib.Path(args.sim_lib_dir)
    lib_build_path_str = str(tmp_lib_build_path / "..")


    devnull = open(devnull, 'w')
    
    print(">>><<< [BUILDING libs]")
    call(["make",
        f"iss"],
          cwd=lib_build_path_str,
          stdout=devnull if not args.verbose else None,
          stderr=devnull if not args.verbose else None,
          timeout=300)
    print(">>><<< [BUILDED libs]")

    # run for every test:
    exectests = {}
    proctests = {}
    
    failed_count = 0
    if not args.j:
        with open(f"report-iss-test-{time()}.txt",'w') as f:
            failures = False
            for cpp in config_test:
            #Use run instead of call
            #timeout ?
                if (not '.cpp' in cpp):
                    cpp += '.cpp'
                run = True
                if args.verbose:
                    print(f"================================================================")
                    print(f"===== {cpp} =====")
                    print(f"================================================================")
                try:
                    call(["make",
                        f"MAIN_C_FILE={cpp}",
                        f"SRC_FOLDER={args.src_folder}",
                        f"ISS_DIR={args.sim_lib_dir}",
                        f"AUX_DIR={args.aux_lib_dir}",
                        f"DUMP_DIR={args.out}",
                        "console"
                        ],cwd=args.target, stdout=devnull if not args.verbose else None, stderr=devnull if not args.verbose else None,
                        timeout=200)
                except KeyboardInterrupt:
                    exit("Stoped by User")
                except:
                    run = False

                cppname = cpp.replace(".cpp","")

                file_dump = pathlib.Path(args.out)
                file_dump /= cppname + ".signature_dump"

                file_reference = pathlib.Path(args.reference_folder)
                file_reference /= cppname + ".reference_output"
                succeded = False
                try:
                    succeded = filecmp.cmp(file_dump, file_reference, shallow=False)
                except:
                    pass
                
                if not succeded:
                    failures = True
                    failed_count += 1

                exectests[cppname] = succeded
                print("{:<10} | {:<40} {:<7}".format(f"{len(exectests)}/{len(config_test)}",cppname, "\033[92msuccess\033[0m" if exectests[cppname] else "\033[91mfailed\033[0m"))

                f.write("{:<10} | {:<40} {:<7}\n".format(f"{len(exectests)}/{len(config_test)}",cppname, "success" if exectests[cppname] else "failed"))
                f.flush()
            
            if(failed_count > 0):
                print(f"\033[91m ({failed_count}/{len(exectests)}) tests failed!\033[0m")
                print(MSG_ENV)
            else:
                print(f"\033[92mAll {len(exectests)} tests were successful\033[0m")
            exit(1 if failures else 0)    
            
                
    else:
        build_id = 0

        for cpp in config_test:
            build_id += 1
            
            proc = Popen(["make",
                f"MAIN_C_FILE={cpp}",
                f"SRC_FOLDER={args.src_folder}",
                f"ISS_DIR={args.sim_lib_dir}",
                f"AUX_DIR={args.aux_lib_dir}",
                f"DUMP_DIR={args.out}",
                f"build_release={build_prefix + str(build_id)}",
                "console"
                ],cwd=args.target, stdout=devnull if not args.verbose else None, stderr=devnull if not args.verbose else None)
            proctests[proc] = cpp
        nfin = True
        while nfin:
            sleep(1)
            tmpfin = True
            removable_keys = []
            for key in proctests:
                poll = key.poll()
                if poll is None:
                    tmpfin = False
                else:                                   
                    cppname = proctests[key].replace(".cpp", "")
                    removable_keys.append(key)

                    file_dump = pathlib.Path(args.out)
                    file_dump /= cppname + ".signature_dump"

                    file_reference = pathlib.Path(args.reference_folder)
                    file_reference /= cppname + ".reference_output"

                    succeded = False
                    try:
                        succeded = filecmp.cmp(file_dump, file_reference, shallow=False)
                    except:
                        pass
                    
                    exectests[cppname] = succeded
                    if not succeded:
                        failed_count += 1

                    print("| {:<40} {:<7}".format(cppname, "\033[92msuccess\033[0m" if exectests[cppname] else "\033[91mfailed\033[0m"))
            for k in removable_keys:
                del proctests[k]

            nfin = not tmpfin
        if(failed_count > 0):
            print(f"\033[91m ({failed_count}/{len(exectests)}) tests failed!\033[0m")
            print(MSG_ENV)
        else:
            print(f"\033[92mAll {len(exectests)} tests were successful\033[0m")
        exit(1 if failed_count > 0 else 0)  
