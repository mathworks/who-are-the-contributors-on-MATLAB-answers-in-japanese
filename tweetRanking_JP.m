%% Script to tweet the top contributors on MATLAB Answers who answer/comment to the Japanese questions.
% Copyright (c) 2022-2023 The MathWorks, Inc.
%% Settings
% Do you want to tweet?
tweet = true;
% Reporting period?
% period = "Monthly";
period = "Weekly";

% setup the baseURL
switch period
    case "Monthly"
       howfar2check = calmonths(1);
       baseURL = "https://jp.mathworks.com/matlabcentral/answers/contributors/" ...
        + "?filter=month";
    case "Weekly"
        howfar2check = calweeks(1);
        baseURL = "https://jp.mathworks.com/matlabcentral/answers/contributors/" ...
        + "?filter=week";
    otherwise
        error("not correct period setting")
end

%% Extract the recent updates on MATLAB Answers
% Check Japapese questions updated over the past howfar2check (week or
% month)
try
    checkdate = datetime;
    page = 0;
    while checkdate > datetime - howfar2check
        page = page + 1;
        xDoc = xmlread(['https://jp.mathworks.com/matlabcentral/answers' ...
            '/questions?language=ja&format=atom&sort=updated+desc&status=answered' ...
            '&page=' num2str(page)]);
        % まず各投稿は <entry></entry>
        allListitems = xDoc.getElementsByTagName('entry');

        % アイテム数だけ配列を確保
        title = strings(allListitems.getLength,1);
        url = strings(allListitems.getLength,1);
        author = strings(allListitems.getLength,1);
        updated = strings(allListitems.getLength,1);

        % 各アイテムから title, url, author 情報を出します。
        for k = 0:allListitems.getLength-1
            thisListitem = allListitems.item(k);

            % Get the title element
            thisList = thisListitem.getElementsByTagName('title');
            thisElement = thisList.item(0);
            % The text is in the first child node.
            title(k+1) = string(thisElement.getFirstChild.getData);

            % Get the link element
            thisList = thisListitem.getElementsByTagName('link');
            thisElement = thisList.item(0);
            % The url is one of the attributes
            url(k+1) = string(thisElement.getAttributes.item(0));

            % Get the author element
            thisList = thisListitem.getElementsByTagName('author');
            thisElement = thisList.item(0);
            childNodes = thisElement.getChildNodes;
            author(k+1) = string(childNodes.item(1).getFirstChild.getData);

            % Get the
            %         <updated>2020-04-18T16:40:12Z</updated>
            thisList = thisListitem.getElementsByTagName('updated');
            thisElement = thisList.item(0);
            updated(k+1) = string(thisElement.getFirstChild.getData);

        end
        %         updated_at = datetime(updated,'InputFormat', "uuuu-MM-dd'T'HH:mm:ss'Z",'TimeZone','UTC');
        updated_at = datetime(updated,'InputFormat', "uuuu-MM-dd'T'HH:mm:ss'Z");
        updated_at.Format = 'uuuu-MM-dd HH:mm:ss';

        % URL は以下の形になっているので、
        % href="https://www.mathworks.com/matlabcentral/answers/477845-bode-simulink-360"
        url = extractBetween(url,"href=""",""""); % URL 部分だけ取得
        entryID = double(extractBetween(url,"answers/","-")); % 投稿IDを別途確保

        tmp = timetable(title, url, author, 'RowTimes', updated_at,...
            'VariableNames',{'titles', 'urls', 'authors'});

        if page == 1
            item_list = tmp;
        else
            item_list = [item_list; tmp];
        end

        checkdate = updated_at(end);
    end

catch ME
    disp(ME)
    FailAnswersRead = true; % 読み込み失敗
    return;
end

%% Check the related users on the above posts
% var users_on_post = [{"pid":21016631,"name":"隆人 山田","image_path":"21016631_1611128788061_DEF.jpg"},
% {"pid":6704456,"name":"Atsushi Ueno","image_path":"6704456_1637834897452.png"}];
item2check = item_list;
users = [];
for ii=1:height(item2check)

    url = item2check.urls(ii);
    try
        txt = webread(url);
    catch ME
        disp("Error at webread. Pause the execution for 60 sec and retry..")
        pause(60)
        txt = webread(url);
    end
    %     href="/matlabcentral/profile/authors/6704456">Atsushi Ueno</a>
    users_on_post = regexp(txt,'href="/matlabcentral/profile/authors/(?:\d+?)">([^<].+?)</a>','tokens');
    users = [users, string(users_on_post)];

end

% unique account
nicknames = unique(users);
idx = nicknames == "MathWorks Support Team";
nicknames(idx) = [];

%% Extract 250 top contributors on MATLAB Answers
perpage = 50;
pages = 5;
ranks = zeros(perpage*pages,1);
names = strings(perpage*pages,1);
for ii=1:pages
    url = baseURL + "&page=" + ii;
    
    a = webread(url);
    b=htmlTree(a);
    c=findElement(b,"td:first-child");
    
    for jj=1:perpage
        index = (ii-1)*perpage+jj;
        tmp = findElement(c(jj),"div:first-child");
        ranks(index) = extractHTMLText(tmp);
        tmp = findElement(c(jj),"H4 > A > SPAN");
        names(index) = extractHTMLText(tmp);
    end
    
end

% Extract those who comment/answer to Japanese posts.
idx = ismember(names,nicknames);
dataset = table(ranks(idx),names(idx),'VariableNames',{'rank','nickname'})


%% Tweet the results

% status = "MATLAB の Q&A サイト：MATLAB Answers" + newline;
% status = status + "日本語質問に回答する Top アカウント (" + period + ")" + newline + newline;
status = "MATLAB Answers の日本語質問に回答する Top アカウント (" + period + ")" + newline + newline;

for ii=1:min(height(dataset),5)
    status = status + "- " + dataset.nickname(ii) + "さん" + newline;
end
status = status + newline + "ありがとうございます！" + newline;
status = status + "詳細："  + baseURL;
disp(status);

if tweet
    try
        py.tweetJPAnswers.tweetV2(status)
    catch ME
        disp(ME)
    end
end
