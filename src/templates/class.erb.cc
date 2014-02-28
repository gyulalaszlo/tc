class <%= type.name  %> {
  // fields
  <%
    var fields = type.as.layout.fields;
    for (var i=0; i < fields.length; ++i)
    {
        var field = fields[i];
  %>
  <%= field.type.name %> <%= field.name %>;
  <% } %>
  // methods sets
  <%
    for (var i=0; i < methods.length; ++i)
    {
        var method_set = methods[i];
  %>
  <%= method_set.access %>:
  <% } %>
};
