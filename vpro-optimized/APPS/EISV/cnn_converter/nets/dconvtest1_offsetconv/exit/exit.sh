echo "[Exit-Script] start"

echo "Checking ISS output against reference"

SIM_FILES="../sim_results/*"
for f in $SIM_FILES
do
    NAME=$(basename $f)
    if [[ -f "../sim_results/$NAME" && -f "../reference/$NAME" ]]; then
        if diff <(xxd "../sim_results/$NAME") <(xxd "../reference/$NAME"); then
            echo "File $NAME matches reference"
        else
            echo "File $NAME doesn't match reference"
        fi
    fi
done

echo "[Exit-Script] done"
