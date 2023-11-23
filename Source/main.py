import os

def print_menu():
    # reset console
    os.system('cls')

    # print meun
    print('Anonymity by Zhonghui')
    
    def print_menu_item(index: int, item: str):
        print(f'{index}. {item}')

    print_menu_item(1, 'All')
    print_menu_item(2, 'Check screen resolution')
    print_menu_item(3, 'Check system path')

def function_check_screen_resolution():
    pass

def function_check_system_path():
    pass

def function_check_system_security():
    pass

def function_check_network_security():
    pass

def run_function(index: int):
    print(f'Run function {index}')

def main_interactive():
    while True:
        print_menu()
        option = int(input())
        run_function(option)

        print('Press Q to Quit')
        option = input()
        if option == 'Q' or option == 'q':
            break

def main_auto_all():
    pass

if __name__=='__main__':
    main_auto_all()