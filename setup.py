from setuptools import setup

with open('btcrelay/requirements.txt') as handle:
    REQUIREMENTS = [_.strip() for _ in handle.readlines()]

# TODO: require python >= 3.9 for importlib.resources.files etc.

setup(
    name='btcrelay',
    version='2024.1a1',
    description='Command Line for BTCRelay',
    license='MIT',
    package_data={
        'btcrelay': ['py.typed'],
        "btcrelay.abi": ["*.bin", "*.json"],
        "btcrelay.deployments": ["*.json"]
    },
    classifiers=[
        'Development Status :: 3 - Alpha',
        'Environment :: Console',
        'License :: OSI Approved :: MIT License',
        'Natural Language :: English',
        'Operating System :: OS Independent',
        'Programming Language :: Python :: 3 :: Only',
        'Programming Language :: Python :: 3.9',
        'Programming Language :: Python :: 3.10',
        'Programming Language :: Python :: 3.11',
        'Programming Language :: Python :: 3.12',
        'Programming Language :: Python :: 3.13',
        'Topic :: Religion',
        'Topic :: System :: Hardware :: Mainframes',
        'Typing :: Typed'
    ],
    entry_points = {'console_scripts': ['btcrelay=btcrelay']},
    packages=['btcrelay', 'btcrelay.abi', 'btcrelay.deployments'],
    py_modules=['__main__'],
    install_requires=REQUIREMENTS
)
