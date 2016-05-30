module IfElseOverParagraphsTest
  OVER_PARAGRAPHS_IF_ELSE = File.join(File.dirname(__FILE__), '..', '..', 'content', 'template', 'if_else', 'test_if_over_paragraphs.docx')
  IF_ELSE_NOT = File.join(File.dirname(__FILE__), '..', '..', 'content', 'template', 'if_else', 'if_else_not.docx')
  IF_ELSE_INCLUDES = File.join(File.dirname(__FILE__), '..', '..', 'content', 'template', 'if_else', 'if_else_includes.docx')
  IF_USING_IMAGE = File.join(File.dirname(__FILE__), '..', '..', 'content', 'template', 'if_else', 'if_using_image.docx')
  IF_SINGLE_QUOTE = File.join(File.dirname(__FILE__), '..', '..', 'content', 'template', 'if_else', 'if_single_quote.docx')

  #DIFFERENT PARAGRAPH LOOPS
  #
  #
  #
  def test_if_else_over_paragraphs
    file = File.new('test_if_over_paragraphs.docx', 'w')
    file.close
    filename = file.path

    doc = Office::WordDocument.new(OVER_PARAGRAPHS_IF_ELSE)
    template = Word::Template.new(doc)
    template.render(
      {'fields' =>
        {
          'a' => '',
          'b' => 'haha',
          'c' => 'lol'
        }
      }, {do_not_render: true})
    template.word_document.save(filename)

    assert File.file?(filename)
    assert File.stat(filename).size > 0

    correct = Office::WordDocument.new(File.join(File.dirname(__FILE__), '..', '..', 'content', 'template', 'if_else', 'correct_render', 'test_if_over_paragraphs.docx'))
    our_render = Office::WordDocument.new(filename)
    assert docs_are_equivalent?(correct, our_render)
  ensure
    File.delete(filename)
  end

  def test_if_else_not
    file = File.new('if_else_not.docx', 'w')
    file.close
    filename = file.path

    doc = Office::WordDocument.new(IF_ELSE_NOT)
    template = Word::Template.new(doc)
    template.render(
      {'fields' =>
        {
          'a' => '',
          'b' => 'haha',
          'c' => 'lol'
        }
      }, {do_not_render: true})
    template.word_document.save(filename)

    assert File.file?(filename)
    assert File.stat(filename).size > 0

    correct = Office::WordDocument.new(File.join(File.dirname(__FILE__), '..', '..', 'content', 'template', 'if_else', 'correct_render', 'if_else_not.docx'))
    our_render = Office::WordDocument.new(filename)
    assert docs_are_equivalent?(correct, our_render)
  ensure
    File.delete(filename)
  end

  def test_if_includes
    file = File.new('if_else_includes.docx', 'w')
    file.close
    filename = file.path

    doc = Office::WordDocument.new(IF_ELSE_INCLUDES)
    template = Word::Template.new(doc)
    template.render(
      {'fields' =>
        {
          'a' => '',
          'b' => 'big yellow submarine',
          'c' => 'no way hosè'
        }
      }, {do_not_render: true})
    template.word_document.save(filename)

    assert File.file?(filename)
    assert File.stat(filename).size > 0

    correct = Office::WordDocument.new(File.join(File.dirname(__FILE__), '..', '..', 'content', 'template', 'if_else', 'correct_render', 'if_else_includes.docx'))
    our_render = Office::WordDocument.new(filename)
    assert docs_are_equivalent?(correct, our_render)
  ensure
    File.delete(filename)
  end

  def test_if_image
    file = File.new('if_using_image.docx', 'w')
    file.close
    filename = file.path

    doc = Office::WordDocument.new(IF_USING_IMAGE)
    template = Word::Template.new(doc)
    template.render(
      {'fields' =>
        {
          'a' => test_image,
          'b' => 'big yellow submarine',
          'c' => 'no way hosè'
        }
      }, {do_not_render: true})
    template.word_document.save(filename)

    assert File.file?(filename)
    assert File.stat(filename).size > 0

    correct = Office::WordDocument.new(File.join(File.dirname(__FILE__), '..', '..', 'content', 'template', 'if_else', 'correct_render', 'if_using_image.docx'))
    our_render = Office::WordDocument.new(filename)
    assert docs_are_equivalent?(correct, our_render)
  ensure
    File.delete(filename)
  end

  def test_if_single_quote
    file = File.new('if_single_quote.docx', 'w')
    file.close
    filename = file.path

    doc = Office::WordDocument.new(IF_SINGLE_QUOTE)
    template = Word::Template.new(doc)
    template.render(
      {'fields' =>
        {
          'a' => 'a',
          'b' => 'b',
          'c' => 'no way hosè'
        }
      }, {do_not_render: true})
    template.word_document.save(filename)

    assert File.file?(filename)
    assert File.stat(filename).size > 0

    correct = Office::WordDocument.new(File.join(File.dirname(__FILE__), '..', '..', 'content', 'template', 'if_else', 'correct_render', 'if_single_quote.docx'))
    our_render = Office::WordDocument.new(filename)
    assert docs_are_equivalent?(correct, our_render)
  ensure
    File.delete(filename)
  end

  private

  def test_image
    image_data = File.open(File.join(File.dirname(__FILE__), '..', '..', 'content', 'test_image.jpg')).read
    Magick::Image.from_blob(image_data)
  end
end
