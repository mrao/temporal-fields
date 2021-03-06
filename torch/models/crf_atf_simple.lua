--
--  Copyright (c) 2016, Facebook, Inc.
--  All rights reserved.
--
--  This source code is licensed under the BSD-style license found in the
--  LICENSE file in the root directory of this source tree. An additional grant
--  of patent rights can be found in the PATENTS file in the same directory.
--
--  The ResNet model definition
--

local nn = require 'nn'
require 'cunn'
require 'loadcaffe'

local function createModel(opt,dataopt)
   local model = loadcaffe.load(opt.pretrainpath .. 'VGG_ILSVRC_16_layers_deploy.prototxt', opt.pretrainpath .. 'VGG_ILSVRC_16_layers.caffemodel','cudnn')

   print(' => Replacing classifier with ' .. opt.nClasses .. '-way classifier')

   model:remove(#model.modules) --remove softmax
   local orig = model:get(#model.modules)
   assert(torch.type(orig) == 'nn.Linear',
      'expected last layer to be fully connected')

   local crf = require('layers/CRF_ATF')
   dataopt = dataopt and dataopt or opt.dataopt
   local linear = crf(opt.batchSize,orig.weight:size(2),false,opt.goals,unpack(dataopt))
   linear.name = "fc8"

   model:remove(#model.modules)
   model:add(linear:cuda())

   if opt.fc7_dropout then
       model.modules[38]:setp(tonumber(opt.fc7_dropout))
   end

   model:cuda()
   model.dataopt = dataopt

   print(tostring(model))
   if opt.cudnn == 'deterministic' then
      model:apply(function(m)
         if m.setMode then m:setMode(1,1,1) end
      end)
   end
   local crfloss = require('layers/CRF_ATFloss')
   local criterion = crfloss(opt,opt.batchSize,orig.weight:size(2),opt.goals,unpack(dataopt))

   return model, criterion
end

return createModel
