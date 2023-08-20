#
# Based on Rscript from:
# "Supplementary Materials for "DeepLineDP: Towards a Deep Learning Approach for Line-Level Defect Prediction""
# https://github.com/awsm-research/DeepLineDP/tree/master
#

library(tidyverse)
library(gridExtra)
library(ModelMetrics)
library(caret)
library(reshape2)
library(pROC)
library(effsize)

get.top.k.tokens = function(df, k)
{
  top.k <- df %>% filter( is.comment.line=="False"  & file.level.ground.truth=="True" & prediction.label=="True" ) %>%
    group_by(test, filename) %>% top_n(k, token.attention.score) %>% select("project","train","test","filename","token") %>% distinct()
  
  top.k$flag = 'topk'

  return(top.k)
}

get.file.level.metrics = function(df.file)
{
  all.gt = df.file$file.level.ground.truth
  all.prob = df.file$prediction.prob
  all.pred = df.file$prediction.label
  
  confusion.mat = confusionMatrix(all.pred, reference = all.gt)
  
  bal.acc = confusion.mat$byClass["Balanced Accuracy"]
  AUC = pROC::auc(all.gt, all.prob)
  
  levels(all.pred)[levels(all.pred)=="False"] = 0
  levels(all.pred)[levels(all.pred)=="True"] = 1
  levels(all.gt)[levels(all.gt)=="False"] = 0
  levels(all.gt)[levels(all.gt)=="True"] = 1
  
  all.gt = as.numeric_version(all.gt)
  all.gt = as.numeric(all.gt)
  
  all.pred = as.numeric_version(all.pred)
  all.pred = as.numeric(all.pred)
  
  MCC = mcc(all.gt, all.pred, cutoff = 0.5) 
  
  if(is.nan(MCC))
  {
    MCC = 0
  }
  
  eval.result = c(AUC, MCC, bal.acc)
  
  return(eval.result)
}

get.file.level.eval.result = function(prediction.dir, method.name)
{
  all_files = list.files(prediction.dir)

  all.auc = c()
  all.mcc = c()
  all.bal.acc = c()
  all.test.rels = c()

  for(f in all_files) # for looping through files
  {
    df = read.csv(paste0(prediction.dir, f))

    if(method.name == "DeepLineDP")
    {
      df = as_tibble(df)
      df = select(df, c(train, test, filename, file.level.ground.truth, prediction.prob, prediction.label))
      
      df = distinct(df)
    }
    
    file.level.result = get.file.level.metrics(df)

    AUC = file.level.result[1]
    MCC = file.level.result[2]
    bal.acc = file.level.result[3]

    all.auc = append(all.auc,AUC)
    all.mcc = append(all.mcc,MCC)
    all.bal.acc = append(all.bal.acc,bal.acc)
    all.test.rels = append(all.test.rels,f)

  }
  
  result.df = data.frame(all.auc,all.mcc,all.bal.acc)

  
  all.test.rels = str_replace(all.test.rels, ".csv", "")
  
  result.df$release = all.test.rels
  result.df$technique = method.name
  
  return(result.df)
}

## get cross-project result

prediction.dir = '../output/prediction/DeepLineDP/cross-project/'

# Add the training set name to generate metrics for to projs
projs = c('activemq') #('activemq', 'camel', 'derby', 'groovy', 'hbase', 'hive', 'jruby', 'lucene', 'wicket')

get.line.level.metrics = function(df_all)
{
  #Force attention score of comment line is 0
  df_all[df_all$is.comment.line == "True",]$token.attention.score = 0

  sum_line_attn = df_all %>% filter(file.level.ground.truth == "True" & prediction.label == "True") %>% group_by(filename,is.comment.line, file.level.ground.truth, prediction.label, line.number, line.level.ground.truth) %>%
    summarize(attention_score = sum(token.attention.score), num_tokens = n())
  sorted = sum_line_attn %>% group_by(filename) %>% arrange(-attention_score, .by_group=TRUE) %>% mutate(order = row_number())
  
  # calculate IFA
  IFA = sorted %>% filter(line.level.ground.truth == "True") %>% group_by(filename) %>% top_n(1, -order)
  total_true = sorted %>% group_by(filename) %>% summarize(total_true = sum(line.level.ground.truth == "True"))
  
  # calculate Recall20%LOC
  recall20LOC = sorted %>% group_by(filename) %>% mutate(effort = round(order/n(),digits = 2 )) %>% filter(effort <= 0.1) %>%
    summarize(correct_pred = sum(line.level.ground.truth == "True")) %>%
    merge(total_true) %>% mutate(recall20LOC = correct_pred/total_true)

  # calculate Effort20%Recall
  effort20Recall = sorted %>% merge(total_true) %>% group_by(filename) %>% mutate(cummulative_correct_pred = cumsum(line.level.ground.truth == "True"), recall = round(cumsum(line.level.ground.truth == "True")/total_true, digits = 2)) %>%
    summarise(effort20Recall = sum(recall <= 0.1)/n())
  
  all.ifa = IFA$order
  all.recall = recall20LOC$recall20LOC
  all.effort = effort20Recall$effort20Recall
  
  result.df = data.frame(all.ifa, all.recall, all.effort)
  
  return(result.df)
}


all.line.result = NULL
all.file.result = NULL


for(p in projs)
{
  actual.pred.dir = paste0(prediction.dir,p,'/') # concatenated path to actual dir
  
  all.files = list.files(actual.pred.dir) 
  
  all.auc = c()
  all.mcc = c()
  all.bal.acc = c()
  all.src.projs = c()
  all.tar.projs = c()
  
  for(f in all.files) # go through all prediction files of a single project
  {
    df = read.csv(paste0(actual.pred.dir,f)) # read a single prediction csv

    f = str_replace(f,'.csv','') 
    f.split = unlist(strsplit(f,'-'))
    target = tail(f.split,2)[1] # gets target project name e.g., 'derby'
    
    df = as_tibble(df) # conver to type tibble = class tbl_df
    
    df.file = select(df, c(train, test, filename, file.level.ground.truth, prediction.prob, prediction.label))
    
    df.file = distinct(df.file) # tibble object, columns specified above, only distinct rows

    file.level.result = get.file.level.metrics(df.file)

    AUC = file.level.result[1]
    MCC = file.level.result[2]
    bal.acc = file.level.result[3]

    all.auc = append(all.auc, AUC)
    all.mcc = append(all.mcc, MCC)
    all.bal.acc = append(all.bal.acc, bal.acc)
    
    all.src.projs = append(all.src.projs, p)
    all.tar.projs = append(all.tar.projs,target)

    tmp.top.k = get.top.k.tokens(df, 1500)
    
    merged_df_all = merge(df, tmp.top.k, by=c('project', 'train', 'test', 'filename', 'token'), all.x = TRUE)
    
    merged_df_all[is.na(merged_df_all$flag),]$token.attention.score = 0
    
    line.level.result = get.line.level.metrics(merged_df_all)
    line.level.result$src = p
    line.level.result$target = target

    all.line.result = rbind(all.line.result, line.level.result)

    print(paste0('finished ',f))
    
  }
  
  file.level.result = data.frame(all.auc,all.mcc,all.bal.acc)
  file.level.result$src = p
  file.level.result$target = all.tar.projs
  
  all.file.result = rbind(all.file.result, file.level.result)

  print(paste0('finished ',p))

}

final.file.level.result = all.file.result %>% group_by(target) %>% summarize(auc = mean(all.auc), balance_acc = mean(all.bal.acc), mcc = mean(all.mcc))
print(paste0('File level results:'))
print(final.file.level.result)

final.line.level.result = all.line.result %>% group_by(target) %>% summarize(recall = mean(all.recall), effort = mean(all.effort), ifa = mean(all.ifa))
print(paste0('Line level results:'))
print(final.line.level.result)
