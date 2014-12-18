find app/views/posts -name \*.html -print | sed 'p;s/.html$/.html.haml/' | xargs -n2 html2haml
