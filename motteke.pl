#!/usr/bin/env perl
use strict;
use warnings;
use utf8;
use Encode (qw/decode_utf8/);

# 標準出力を自動的にutf8にする (Wide character なんちゃら避け)
binmode STDOUT, ':utf8';

main();

sub main {
    # TSVファイルからアイテムデータを読み込む
    my $file_path = './items.tsv';
    my $items = load_tsv($file_path);

    # C列"数量"に登場する言葉を、ユーザーに確認するために取り出しておく
    my $words = get_words($items);
    #my $conditions = get_conditions($items);

    # ユーザーから旅の条件を聞き出す
    my $conditions = ask_conditions($words);

    # 各アイテムの必要数量を求める
    calculate_quantities($items, $conditions);

    # 持ち物リストを出力する
    print_item_list($items);

    print "\n良い旅を！\n";
}

# TSVからアイテムデータを読み込んで返す
sub load_tsv {
    my $file_path = shift;

    # 対象TSVの改行コードを指定
    local $/ = "\r\n";

    my @rows;
    open my $fh, "<", $file_path or die;
    while ( defined(my $row = <$fh>) ) {
        chomp($row);
        if ( defined $row ) {
            # 外から読み込んだ文字列なのでutf8フラグをつけてあげる
            push @rows, decode_utf8($row);
        }
    }

    # 先頭行は要らないので捨てる
    shift @rows;

    # 1行ごとにタブ文字で分割し、ハッシュに変換する
    my @items;
    for my $row ( @rows ) {
        my @cols = split(/\t/, $row);

        push @items, {
            container    => $cols[0], # A列 入れ物
            name         => $cols[1], # B列 品名
            quantity     => $cols[2], # C列 数量
            unit         => $cols[3], # D列 単位
        };
    }

    return \@items;
}

# C列 "数量" に登場する言葉を取りまとめて返す
sub get_words {
    my $items = shift;

    # まずは取り出す
    my @words;
    for my $item ( @$items ) {
        my $str = $item->{quantity}; # C列 数量

        # 数字と記号は無視
        $str =~ s/\d|\W/ /g;

        push @words, split(/ +/, $str);
    }

    # ダブりを無くすために、いったんハッシュのキーにしてから配列に戻す
    my %hash;
    for my $word ( @words ) {
        # 未定義や空文字は邪魔なので無視
        if ( ($word // '') eq '' ) {
            next;
        }

        $hash{$word} //= 1;
    }
    my @unique_words = sort keys %hash;

    return \@unique_words;
}

# 受け取った語群を元に、
# ユーザーから旅の条件を聞き出して返す
sub ask_conditions {
    my $words = shift;

    print "何泊しますか？ 自然数を入力してください。: ";
    my $number_of_nights = <STDIN>;
    chomp($number_of_nights);

    print "\n以下の質問は、該当する場合のみ'y'と答えてください。\n";
    my %conditions = (
        '泊数' => $number_of_nights // 0,
    );

    for my $word ( @$words ) {
        if ( $word eq '泊数' ) {
            next; # 上で確認済みだし、yes/no問題ではないのでスキップ
        }

        print $word . "？: ";
        my $input = <STDIN>;
        chomp($input);

        if ( ($input // '') eq 'y' ) {
            $conditions{$word} = 1;
        }
        else {
            $conditions{$word} = 0;
        }
    }

    return \%conditions;
}

# アイテムデータと条件を受け取り、数量を数値化する
sub calculate_quantities {
    my $items = shift;
    my $conditions = shift;

    # 長い言葉から優先的に置換したいので、ソートしておく
    # たとえば、"寒い" と "超寒い" を数字に置換するとき、
    # "寒い" を先に置換するとおかしなことになってしまうので。
    my @words = sort { length($b) <=> length($a) } keys %$conditions;

    for my $item ( @$items ) {
        my $quantity = $item->{quantity};

        if ( $quantity =~ m/^\d+$/ ) {
            $item->{numeric_quantity} = $quantity;
        }
        else {
            for my $word ( @words ) {
                my $val = $conditions->{$word};
                $quantity =~ s/$word/$val/g;
            }

            # 文字列 $quantity をプログラムとして解釈する
            # たとえば、eval("2 + 1") なら返値は 3 になる
            $item->{numeric_quantity} = eval($quantity);
        }
    }
}

# アイテムデータを受け取り、持ち物リストとして出力する
sub print_item_list {
    my $items = shift;

    print "\n";
    print '-' x 20, "\n";
    print "もってけリスト\n";
    print '-' x 20, "\n";

    my $i = 0;
    for my $item ( @$items ) {
        if ( $item->{numeric_quantity} ) {
            print sprintf("%02d %s %s * %s%s\n",
                $i++,
                $item->{container},
                $item->{name},
                $item->{numeric_quantity},
                $item->{unit},
            );
        }
    }
}

exit(0);

