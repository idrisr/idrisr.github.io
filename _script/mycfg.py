from traitlets.config import get_config
from nbconvert.preprocessors import Preprocessor

import re
import ast

class YAMLFrontMatterPreProcessor(Preprocessor):
    def _check_front_matter(self, cell):
        pattern = re.compile(r"^#frontmatter")
        return pattern.match(cell.source)
    
    def preprocess(self, nb, resources):
        if self._check_front_matter(nb.cells[0]):
            resources['front_matter'] = ast.literal_eval(nb.cells[0]['source'])
            nb.cells = nb.cells[1:]
        else:
            resources['front_matter'] = {}
        return nb, resources

class HideCell(Preprocessor):
    def _check_hidden(self, cell):
        pattern = re.compile(r"^#hide")
        return not pattern.match(cell.source)

    def preprocess(self, nb, resources):
        nb.cells = list(filter(self._check_hidden, nb.cells))
        #  if self._check_front_matter(nb.cells[0]):
            #  resources['front_matter'] = ast.literal_eval(nb.cells[0]['source'])
            #  nb.cells = nb.cells[1:]
        #  else:
            #  resources['front_matter'] = {}
        return nb, resources


def jekyllify(path):
    return '<img src="{{site.baseurl | append: "/assets/images/' + path + '"}}">'


c = get_config()
c.TemplateExporter.template_file = "my.tpl"
c.MarkdownExporter.preprocessors = [YAMLFrontMatterPreProcessor, HideCell]
c.ExtractOutputPreprocessor.output_filename_template = '{unique_key}_{cell_index}_{index}{extension}'
c.MarkdownExporter.enabled = True
c.FilesWriter.build_directory = "moveme"
c.Application.log_level = 0
c.TemplateExporter.filters = {'jekyllify': jekyllify}

#  jupyter nbconvert --config mycfg.py --to markdown  99-sample-notebook.ipynb
