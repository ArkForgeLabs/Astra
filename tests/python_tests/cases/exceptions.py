result = None
try:
    result = 10 // 2
except:
    result = -1
finally:
    print(result)

result2 = None
try:
    result2 = 42
finally:
    print(result2)
