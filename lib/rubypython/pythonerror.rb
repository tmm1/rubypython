require 'rubypython/python'
require 'rubypython/macros'

# Raised when an error occurs in the Python interpreter.
class RubyPython::PythonError < RuntimeError
  # @param [String] typeName the class name of the Python error
  # @param [String] msg the message attached to the Python error
  def initialize(typeName, msg)
    @type = typeName
    super([typeName, msg].join(': '))
  end

  # This method should be called when an error has occured in the Python
  # interpreter. This acts as factory function for PythonError objects.
  # The function fetchs calls {fetch} to get the error information from
  # the Python interpreter and uses this to build a PythonError object. It
  # then calls {clear} to clear the error flag of the python interpreter
  # @return [PythonError] an error enscapsulating the Python error
  def self.handle_error
    rbType, rbValue, rbTraceback = fetch()

    if not rbValue.null?
      msg = rbValue.getAttr("__str__").callObject RubyPython::PyObject.buildArgTuple
      msg = msg.rubify
    else
      msg = nil
    end

    # Decrease the reference count. This will happen anyway when they go
    # out of scope but might as well.
    rbValue.xDecref
    rbTraceback.xDecref
    pyName = rbType.getAttr("__name__")

    rbType.xDecref
    rbName = pyName.rubify
    pyName.xDecref

    RubyPython::PythonError.clear
    RubyPython::PythonError.new(rbName, msg)
  end

  # A wrapper to the Python C API PyErr_Fetch function.
  # @return [Array<PyObject>] an array containing three {PyObject}
  # instances. representing the Type, Value, and stacktrace of the python
  # error respectively.
  def self.fetch
    typePointer = FFI::MemoryPointer.new :pointer
    valuePointer = FFI::MemoryPointer.new :pointer
    tracebackPointer = FFI::MemoryPointer.new :pointer

    RubyPython::Python.PyErr_Fetch typePointer, valuePointer, tracebackPointer

    rbType = RubyPython::PyObject.new typePointer.read_pointer
    rbValue = RubyPython::PyObject.new valuePointer.read_pointer
    rbTraceback = RubyPython::PyObject.new tracebackPointer.read_pointer
    [rbType, rbValue, rbTraceback]
  end

  # Determines whether an error has occured in the python interpreter.
  def self.error?
    !RubyPython::Python.PyErr_Occurred.null?
  end

  # Resets the Python interpreter error flag
  # @return [void]
  def self.clear
    RubyPython::Python.PyErr_Clear
  end
end
