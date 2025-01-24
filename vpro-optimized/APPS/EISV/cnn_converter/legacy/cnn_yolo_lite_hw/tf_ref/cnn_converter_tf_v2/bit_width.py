
# Returns the number of bits necessary to represent an integer in binary, 2-complement format
def bit_width(a, b):
    if a > b:
        min_value = b
        max_value = a
    else:
        min_value = a
        max_value = b

    i = 0
    while max_neg_nint[i] > min_value or max_pos_nint[i] < max_value:
        i+=1

    #value = max(abs(min_value), abs(max_value)+1)
    #width = int(math.ceil(math.log2(value))+1)
    # print("min: ", min_value, ", max: ", max_value, " -> req bit width: ", width)
    return i

max_precision = 24
# maximal number with only fraction bits
max_fractions = []
for i in range(max_precision+1):
    if i == 0:
        max_fractions.append(0)
        continue
    max_fractions.append(max_fractions[i-1]+1/(2**i))

# maximal pos number with only integer bits
max_pos = []
for i in range(max_precision+1):
    max_pos.append(2**(i-1)-1)

# maximal neg number with only integer bits
max_neg = []
for i in range(max_precision+1):
    max_neg.append(-2**(i-1))

max_pos_nint = []
for i in range(max_precision+1):
    max_pos_nint.append(max_pos[i] + max_fractions[max_precision-i])

max_neg_nint = max_neg

# print("Fixpoint Format and related Min-/Max-values:")
# for i in range(max_precision+1):
#     print("fpf", i, ".", (max_precision-i), ": \t[min: ", max_neg_nint[i], ", \t max: ", max_pos_nint[i], "\t]" )

