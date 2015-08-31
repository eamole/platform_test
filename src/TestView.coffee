#{View}=require "./View.js"

class TestView extends View
  constructor : ->
    super "TestView"  # not too sure what good this does

  init : (data) =>
    super data

  render : (data) =>
    super data
    """

      Hello World from #{@name}

    """

# hugely important - when loading these view - I can refer to them as new View without knowing their actual name
#exports.View=TestView  # only for node