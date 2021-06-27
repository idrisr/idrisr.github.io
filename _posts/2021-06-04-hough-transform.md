---
toc: True
title: Hough Transform
published: False
---


```python
import pandas as pd
import numpy as np
import matplotlib.pyplot as plt
```

Lately I've been working with the hough transform, a pre deep learning technique used in computer vision to determine whether a straight line exists in an image.  For simplicity, let's only consider binary images, images which are a 2d matrix of boolean values where `True` indicates white and `False` indicates black.  We can create such an image like so:


```python
img = np.array([0, 1, 0]*3).reshape(3, -1)
```


```python
plt.matshow(img, cmap='gray');
```


    
<img src="{{site.baseurl | append: "/assets/images/output_5_0.png"}}">
    


In this simple 3x3 image, I want to find where the lines are. There is a vertical line at 1, but how can we create a function to indicate this?  Turns out some smart guy named Hough figured this out about forty years ago. Our 2d image can be represented by the following function

$$
f(x, y) \rightarrow \text{Bool}
$$

The $x$ and the $y$ are the horizontal and vertical offsets from the origin, and our function maps those inputs to a boolean value. Any straing line in the image can be parametized by its slope and intercept. Think junior high math here:

$$
y = mx+b
$$

Every line can be parametized by the slope $m$ and the intercept $b$. There are infinite number of possible combinations. To make this useful, we need to only consider a finite number of possibile $y$ and $m$ values.

For a line to exist in the image, any point on the line in the image must be white. Another way to think about this is that each white point on the image can any number of lines going through it.



```python
img.sum(axis=1)
```




    array([1, 1, 1])




```python
img.sum(axis=0)
```




    array([0, 3, 0])




```python

```
