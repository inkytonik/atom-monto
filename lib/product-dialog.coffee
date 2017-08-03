# atom-monto Atom package for Monto Disintegrated Development Environment
# Copyright (C) 2016-7 Anthony M. Sloane
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

SelectListView = require 'atom-select-list'

module.exports =
class ProductDialog
  constructor: (@pkg, @isHTML) ->
    @selectListView = new SelectListView {
      items: atom.config.get('monto.productList')

      elementForItem: (product) ->
        li = document.createElement('li')
        div = document.createElement('div')
        div.textContent = product
        li.appendChild(div)
        li

      didConfirmSelection: (product) =>
        @pkg.openViewOnProduct(product, @isHTML)
        @pkg.closeProductDialog()

      didConfirmEmptySelection: () =>
        @pkg.closeProductDialog()

      didCancelSelection: () =>
        @pkg.closeProductDialog()
    }
    @element = @selectListView.element
