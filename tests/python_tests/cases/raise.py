try:
    raise ValueError("oops")
except ValueError as e:
    print(str(e))

try:
    raise TypeError("bad type")
except (ValueError, TypeError) as e:
    print(str(e))

try:
    raise RuntimeError("runtime")
except:
    print("caught")

result = None
try:
    result = 42
except:
    result = -1
finally:
    print(result)