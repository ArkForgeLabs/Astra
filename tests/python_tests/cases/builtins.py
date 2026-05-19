class A:
    pass

class B(A):
    pass

class C(B):
    pass

c = C()
print(1 if isinstance(c, A) else 0)
print(1 if isinstance(42, int) else 0)
print(1 if isinstance("hello", str) else 0)
print(1 if issubclass(B, A) else 0)
print(len([1, 2, 3]))
