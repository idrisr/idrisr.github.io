---
---

# Using Kaggle API and skipping the command line


```python
import kaggle
```

The Kaggle API documentation is oriented around command line usage. I wanted to use the API directly in my own python code without using the `subprocess` module, since that wasn't necessary as the entire kaggle API module is written in Python. I started to read the source code, and here I'm sharing what I've found.

# `!kaggle`

The logical place to start this journey is an understanding of what the `kaggle` command line program does. 


```python
!which kaggle
```

    /Users/id/nbs/venv/bin/kaggle



```python
!cat /Users/id/nbs/venv/bin/kaggle
```

    #!/Users/id/nbs/venv/bin/python3.7
    # -*- coding: utf-8 -*-
    import re
    import sys
    from kaggle.cli import main
    if __name__ == '__main__':
        sys.argv[0] = re.sub(r'(-script\.pyw|\.exe)?$', '', sys.argv[0])
        sys.exit(main())


The kaggle script is automatically created by `pip` when you install the package. `pip` reads the `setup.py` file and looks for the `entry_points` key, and then it creates a command line program automatically for you. As you can see from above, it's a very short script and all it does is modify `sys.argv` and then call the `main` function from the `kaggle.cli` module.

## `argparse`

The next part of this journey is an understanding of how the command line options are parsed. The kaggle API uses the `argparse` package from the standard library to map from command line options in `sys.argv` into a python object. The parser is built in `kaggle.cli.main` - the entry point of the command line program `kaggle`.

The `cli` module is about 1000 lines long, and most of it is for setting up the `argparse` options. The critical bit we're interested in are these [lines](https://github.com/Kaggle/kaggle-api/blob/49057db362903d158b1e71a43d888b981dd27159/kaggle/cli.py#L60) (some lines excluded for brevity) :

```python
args = parser.parse_args()
command_args = {}
command_args.update(vars(args))
del command_args['func']
del command_args['command']
out = args.func(**command_args)
```

First we parse the arguments into `args` - it now has all the information needed to run the command. The callable `args.func` is called with the arguments parsed from the command line. So now all we have to do is print the values of `args.func` and `command_args`, and we can see how the command line options connect to the python code.

Add these lines after `args.func` is called and we can see the information we're after. 

```
print('callable: {}'.format(args.func.__qualname__))
print('options: {}'.format(command_args))
```

I've excluded the output from theses commands for brevity.


```python
!kaggle c list
```

    callable: KaggleApi.competitions_list_cli
    options: {'group': None, 'category': None, 'sort_by': None, 'page': 1, 'search': None, 'csv_display': False}



```python
!kaggle d list
```

    callable: KaggleApi.dataset_list_cli
    options: {'sort_by': None, 'size': None, 'file_type': None, 'license_name': None, 'tag_ids': None, 'search': None, 'mine': False, 'user': None, 'page': 1, 'csv_display': False, 'max_size': None, 'min_size': None}



```python
!kaggle k list
```

    callable: KaggleApi.kernels_list_cli
    options: {'mine': False, 'page': 1, 'page_size': 20, 'search': None, 'csv_display': False, 'parent': None, 'competition': None, 'dataset': None, 'user': None, 'language': None, 'kernel_type': None, 'output_type': None, 'sort_by': None}


# Conclusion

Now you can see which function was called and its arguments. This should be a good jumping off point to then incorporate the python code directly, and skipping the command line usage!

I hope this helps someone to use and understand the kaggle API!
